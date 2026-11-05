import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const PlannerApp());

const blue = Color(0xFF168FF0);
const page = Color(0xFFF0F4F7);
const months = ['فروردین','اردیبهشت','خرداد','تیر','مرداد','شهریور','مهر','آبان','آذر','دی','بهمن','اسفند'];
const weekdays = ['شنبه','یکشنبه','دوشنبه','سه‌شنبه','چهارشنبه','پنجشنبه','جمعه'];

class TaskItem {
  TaskItem({required this.id, required this.title, required this.start, required this.end, this.done=false, this.attachments=const []});
  final String id, title;
  final DateTime start, end;
  final bool done;
  final List<Map<String,dynamic>> attachments;
  Map<String,dynamic> toJson()=>{'id':id,'title':title,'start':start.toIso8601String(),'end':end.toIso8601String(),'done':done,'attachments':attachments};
  factory TaskItem.fromJson(Map<String,dynamic> j)=>TaskItem(
    id:j['id'], title:j['title'], start:DateTime.parse(j['start']), end:DateTime.parse(j['end']),
    done:j['done']??false, attachments:List<Map<String,dynamic>>.from((j['attachments']??[]).map((e)=>Map<String,dynamic>.from(e))));
  TaskItem copy({String? title, DateTime? start, DateTime? end, bool? done, List<Map<String,dynamic>>? attachments}) =>
    TaskItem(id:id,title:title??this.title,start:start??this.start,end:end??this.end,done:done??this.done,attachments:attachments??this.attachments);
}

class PlannerApp extends StatelessWidget {
  const PlannerApp({super.key});
  @override Widget build(BuildContext context)=>MaterialApp(
    debugShowCheckedModeBanner:false, title:'برنامه‌ریز',
    locale:const Locale('fa','IR'), supportedLocales:const [Locale('fa','IR')],
    localizationsDelegates:GlobalMaterialLocalizations.delegates,
    theme:ThemeData(useMaterial3:true, colorScheme:ColorScheme.fromSeed(seedColor:blue), scaffoldBackgroundColor:page,
      fontFamily:null, appBarTheme:const AppBarTheme(backgroundColor:page, foregroundColor:Colors.black)),
    home:const HomePage());
}

class HomePage extends StatefulWidget { const HomePage({super.key}); @override State<HomePage> createState()=>_HomePageState(); }
class _HomePageState extends State<HomePage> {
  List<TaskItem> tasks=[]; int tab=0; Jalali shown=Jalali.now(); bool loading=true;
  @override void initState(){super.initState(); _load();}
  Future<void> _load() async {
    final p=await SharedPreferences.getInstance();
    final raw=p.getString('tasks_v1');
    if(raw!=null){try{tasks=(jsonDecode(raw) as List).map((e)=>TaskItem.fromJson(Map<String,dynamic>.from(e))).toList();}catch(_){tasks=[];}}
    if(mounted)setState(()=>loading=false);
  }
  Future<void> _save() async {final p=await SharedPreferences.getInstance(); await p.setString('tasks_v1',jsonEncode(tasks.map((e)=>e.toJson()).toList()));}
  String dateText(DateTime d){final j=d.toJalali(); return '${j.day} ${months[j.month-1]} ${j.year}';}
  String timeText(DateTime d)=>'${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
  List<TaskItem> get visible=>tasks.where((t){
    if(tab!=1)return true;
    final j=t.start.toJalali();
    return j.year==shown.year && j.month==shown.month;
  }).toList()..sort((a,b)=>a.start.compareTo(b.start));

  Future<void> _edit([TaskItem? old]) async {
    final result=await showModalBottomSheet<TaskItem>(context:context,isScrollControlled:true,backgroundColor:Colors.transparent,
      builder:(_)=>TaskEditor(existing:old));
    if(result!=null){setState((){final i=tasks.indexWhere((e)=>e.id==result.id); if(i<0){tasks.add(result);}else{tasks[i]=result;}}); await _save();}
  }
  Future<void> _toggle(TaskItem t) async {setState((){final i=tasks.indexOf(t);tasks[i]=t.copy(done:!t.done);});await _save();}
  Future<void> _delete(TaskItem t) async {setState(()=>tasks.removeWhere((e)=>e.id==t.id));await _save();}
  @override Widget build(BuildContext context){
    if(loading)return const Scaffold(body:Center(child:CircularProgressIndicator()));
    return Scaffold(
      appBar:tab==1?AppBar(title:Row(children:[
        IconButton(onPressed:()=>setState(()=>shown=shown.addMonths(-1)),icon:const Icon(Icons.chevron_left)),
        Expanded(child:Center(child:Text('${months[shown.month-1]} ${shown.year}',style:const TextStyle(fontSize:21)))),
        IconButton(onPressed:()=>setState(()=>shown=shown.addMonths(1)),icon:const Icon(Icons.chevron_right)),
      ])):null,
      body:SafeArea(child:tab==2?_mine():tab==1?_calendar():_tasks()),
      floatingActionButton:tab==2?null:FloatingActionButton(onPressed:()=>_edit(),backgroundColor:blue,foregroundColor:Colors.white,child:const Icon(Icons.add,size:32)),
      bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(v)=>setState(()=>tab=v),backgroundColor:page,
        destinations:const [NavigationDestination(icon:Icon(Icons.list_alt),label:'کارها'),NavigationDestination(icon:Icon(Icons.calendar_month),label:'تقویم'),NavigationDestination(icon:Icon(Icons.person),label:'من')]),
    );
  }
  Widget _tasks()=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    const SizedBox(height:14),Padding(padding:const EdgeInsets.symmetric(horizontal:18),child:Text('همهٔ کارها',style:Theme.of(context).textTheme.titleLarge)),
    Expanded(child:visible.isEmpty?const Center(child:Text('هنوز کاری ثبت نشده است')):ListView.builder(padding:const EdgeInsets.fromLTRB(16,12,16,90),itemCount:visible.length,itemBuilder:(_,i)=>_taskCard(visible[i]))),
  ]);
  Widget _calendar()=>Column(children:[
    Padding(padding:const EdgeInsets.fromLTRB(12,4,12,8),child:Row(children:List.generate(7,(i)=>Expanded(child:Center(child:Text(weekdays[i],style:const TextStyle(color:Colors.blueGrey,fontSize:12))))))),
    _monthGrid(),
    const Divider(height:1),
    Expanded(child:visible.where((t){final j=t.start.toJalali();return j.year==shown.year&&j.month==shown.month&&j.day==shown.day;}).isEmpty?const Center(child:Text('برای این روز کاری ثبت نشده')):ListView(children:visible.where((t){final j=t.start.toJalali();return j.year==shown.year&&j.month==shown.month&&j.day==shown.day;}).map(_taskCard).toList())),
  ]);
  Widget _monthGrid(){
    final first=Jalali(shown.year,shown.month,1); final offset=first.weekDay-1; final count=first.monthLength;
    return Padding(padding:const EdgeInsets.symmetric(horizontal:10),child:GridView.builder(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:7,childAspectRatio:1.25),itemCount:((offset+count+6)~/7)*7,itemBuilder:(_,i){
      final day=i-offset+1;if(day<1||day>count)return const SizedBox();
      final selected=day==shown.day;
      final has=tasks.any((t){final j=t.start.toJalali();return j.year==shown.year&&j.month==shown.month&&j.day==day;});
      return InkWell(borderRadius:BorderRadius.circular(30),onTap:()=>setState(()=>shown=Jalali(shown.year,shown.month,day)),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
        Container(width:36,height:36,alignment:Alignment.center,decoration:BoxDecoration(color:selected?blue:null,shape:BoxShape.circle),child:Text('$day',style:TextStyle(color:selected?Colors.white:Colors.black,fontWeight:selected?FontWeight.bold:FontWeight.normal))),
        if(has)Container(width:5,height:5,decoration:const BoxDecoration(color:blue,shape:BoxShape.circle)),
      ]));
    }));
  }
  Widget _mine()=>Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
    const CircleAvatar(radius:34,backgroundColor:Color(0xFFD7EAF8),child:Icon(Icons.person,color:blue,size:38)),
    const SizedBox(height:12),const Text('برنامه‌ریز شخصی',style:TextStyle(fontSize:20)),
    const SizedBox(height:20),Text('کارهای انجام‌شده: ${tasks.where((t)=>t.done).length}'),
    Text('کارهای باقی‌مانده: ${tasks.where((t)=>!t.done).length}'),
  ]));
  Widget _taskCard(TaskItem t)=>Card(color:Colors.white,elevation:0,margin:const EdgeInsets.only(bottom:10),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(15)),child:ListTile(
    leading:Checkbox(value:t.done,onChanged:(_)=>_toggle(t),activeColor:blue),
    title:Text(t.title,style:TextStyle(decoration:t.done?TextDecoration.lineThrough:null)),
    subtitle:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text('${dateText(t.start)}  •  ${timeText(t.start)} تا ${timeText(t.end)}'),
      if(t.attachments.isNotEmpty)Padding(padding:const EdgeInsets.only(top:5),child:Wrap(spacing:5,children:t.attachments.take(4).map((a)=>Container(width:26,height:26,decoration:BoxDecoration(color:page,borderRadius:BorderRadius.circular(6)),child:a['image']==true?ClipRRect(borderRadius:BorderRadius.circular(6),child:Image.memory(base64Decode(a['data']),fit:BoxFit.cover)):const Icon(Icons.attach_file,size:16))).toList())),
    ]),
    trailing:PopupMenuButton<String>(onSelected:(v){if(v=='edit')_edit(t);if(v=='delete')_delete(t);},itemBuilder:(_)=>const [PopupMenuItem(value:'edit',child:Text('ویرایش')),PopupMenuItem(value:'delete',child:Text('حذف'))]),
  ));
}

class TaskEditor extends StatefulWidget {const TaskEditor({super.key,this.existing});final TaskItem? existing;@override State<TaskEditor> createState()=>_TaskEditorState();}
class _TaskEditorState extends State<TaskEditor>{
  late TextEditingController title;late DateTime start,end;List<Map<String,dynamic>> attachments=[];
  @override void initState(){super.initState();final t=widget.existing;title=TextEditingController(text:t?.title??'');final now=DateTime.now();start=t?.start??DateTime(now.year,now.month,now.day,9);end=t?.end??DateTime(now.year,now.month,now.day,10);attachments=List<Map<String,dynamic>>.from(t?.attachments??[]);}
  @override void dispose(){title.dispose();super.dispose();}
  String dateLabel(DateTime d){final j=d.toJalali();return '${j.day} ${months[j.month-1]} ${j.year}';}
  Future<void> chooseDate()async{
    final initial=start.toJalali();final picked=await showDialog<Jalali>(context:context,builder:(ctx){int y=initial.year,m=initial.month,d=initial.day;return StatefulBuilder(builder:(ctx,setD)=>AlertDialog(title:const Text('انتخاب تاریخ شمسی'),content:Column(mainAxisSize:MainAxisSize.min,children:[
      Row(children:[Expanded(child:DropdownButton<int>(isExpanded:true,value:m,items:List.generate(12,(i)=>DropdownMenuItem(value:i+1,child:Text(months[i]))),onChanged:(v)=>setD(()=>m=v!))),const SizedBox(width:8),Expanded(child:DropdownButton<int>(isExpanded:true,value:y,items:List.generate(11,(i)=>DropdownMenuItem(value:initial.year-5+i,child:Text('${initial.year-5+i}'))),onChanged:(v)=>setD(()=>y=v!)))]),
      DropdownButton<int>(value:d.clamp(1,Jalali(y,m,1).monthLength),items:List.generate(Jalali(y,m,1).monthLength,(i)=>DropdownMenuItem(value:i+1,child:Text('${i+1}'))),onChanged:(v)=>setD(()=>d=v!)),
    ]),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('لغو')),FilledButton(onPressed:()=>Navigator.pop(ctx,Jalali(y,m,d.clamp(1,Jalali(y,m,1).monthLength))),child:const Text('تأیید'))]));});
    if (picked != null) {
      setState(() {
        final g = picked.toDateTime();
        final newStart = DateTime(g.year, g.month, g.day, start.hour, start.minute);
        final duration = end.difference(start);
        start = newStart;
        end = newStart.add(duration.isNegative ? const Duration(hours: 1) : duration);
      });
    }
  }
  Future<void> chooseTime(bool isStart)async{final old=isStart?start:end;final p=await showTimePicker(context:context,initialTime:TimeOfDay.fromDateTime(old),builder:(c,w)=>Directionality(textDirection:TextDirection.rtl,child:w!));if(p!=null)setState(()=>isStart?start=DateTime(start.year,start.month,start.day,p.hour,p.minute):end=DateTime(end.year,end.month,end.day,p.hour,p.minute));}
  Future<void> addFiles()async{
    final res=await FilePicker.platform.pickFiles(allowMultiple:true,withData:true,type:FileType.any);
    if(res==null)return;
    for(final f in res.files){if(f.bytes==null)continue;final isImg=RegExp(r'^(png|jpe?g|gif|webp|bmp)$').hasMatch((f.extension??'').toLowerCase());attachments.add({'name':f.name,'data':base64Encode(f.bytes!), 'image':isImg});}
    if(mounted)setState((){});
  }
  @override Widget build(BuildContext context)=>Directionality(textDirection:TextDirection.rtl,child:Padding(padding:EdgeInsets.only(bottom:MediaQuery.of(context).viewInsets.bottom),child:Container(padding:const EdgeInsets.all(20),decoration:const BoxDecoration(color:Colors.white,borderRadius:BorderRadius.vertical(top:Radius.circular(24))),child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text(widget.existing==null?'کار جدید':'ویرایش کار',style:const TextStyle(fontSize:21,fontWeight:FontWeight.bold)),
    const SizedBox(height:14),TextField(controller:title,decoration:const InputDecoration(labelText:'عنوان کار',border:OutlineInputBorder())),
    const SizedBox(height:12),OutlinedButton.icon(onPressed:chooseDate,icon:const Icon(Icons.calendar_month),label:Text(dateLabel(start))),
    Row(children:[Expanded(child:OutlinedButton(onPressed:()=>chooseTime(true),child:Text('شروع: ${start.hour.toString().padLeft(2,'0')}:${start.minute.toString().padLeft(2,'0')}'))),const SizedBox(width:8),Expanded(child:OutlinedButton(onPressed:()=>chooseTime(false),child:Text('پایان: ${end.hour.toString().padLeft(2,'0')}:${end.minute.toString().padLeft(2,'0')}')))]),
    Align(alignment:Alignment.centerRight,child:TextButton.icon(onPressed:addFiles,icon:const Icon(Icons.attach_file),label:Text('افزودن پیوست (${attachments.length})'))),
    if(attachments.isNotEmpty)Wrap(spacing:6,children:attachments.asMap().entries.map((e)=>InputChip(label:Text(e.value['name'],overflow:TextOverflow.ellipsis),onDeleted:()=>setState(()=>attachments.removeAt(e.key)))).toList()),
    const SizedBox(height:12),SizedBox(width:double.infinity,child:FilledButton(onPressed:(){
      final name=title.text.trim();if(name.isEmpty){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('عنوان کار را وارد کن')));return;}
      if(!end.isAfter(start)){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('زمان پایان باید بعد از شروع باشد')));return;}
      final old=widget.existing;Navigator.pop(context,TaskItem(id:old?.id??DateTime.now().microsecondsSinceEpoch.toString(),title:name,start:start,end:end,done:old?.done??false,attachments:attachments));
    },child:const Text('ذخیره'))),
  ])))));
}
