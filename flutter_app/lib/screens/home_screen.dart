import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/settings.dart';
import '../db/capture_db_service.dart';
import '../db/snapshot_db_service.dart';
import '../db/capture.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../services/folder_generation.dart';
import '../services/name_generation.dart';
import '../services/capture_service.dart';
import 'dart:async';
import '../models/capture_result.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin, TrayListener {
  final service = SettingsService();
  final captureDB = CaptureDBService();
  final captureService = CaptureService();
  final snapshotService = SnapshotService();
  final String defaultCaptureName = "Verena_Capture";

  double windowWidth = 230;
  bool isRunning = false;
  bool openSettings = false;
  bool ignoreNextOutsideTap = false;
  bool editingCaptureName = false;
  bool isCapturing = false;

  String status = "Idle";
  late String snapshotInterval;
  late int currentCapture;
  Map<String, int> intervalList = {
    "15 seconds": 15,
    "30 seconds": 30,
    "1 minute": 60,
    "2 minutes": 120,
    "5 minutes": 300,
  };
  final valueListenable = ValueNotifier<String?>("30 seconds");
  List<Capture> captures = [];
  Capture? currentProjectCapture;
  List<bool> captureCheckBoxList = [];
  int currentCaptureIndex = -1;
  List<int> selectedCaptures = [];
  Uint8List lastHash = Uint8List(32);

  late final AnimationController _controller;
  final ScrollController _scrollController = ScrollController();
  final ScrollController _scrollController2 = ScrollController();
  final TextEditingController _createCaptureController = TextEditingController(
    text: "",
  );
  final TextEditingController _captureEditController = TextEditingController(
    text: "test",
  );
  final FocusNode _captureEditFocusNode = FocusNode();

  Future<void> _handleTrayIcon() async {
    await trayManager.setIcon('assets/verena.ico');
    await trayManager.setToolTip("Verena");
    Menu menu = Menu(
      items: [
        MenuItem(key: 'show_window', label: 'Show Window'),
        MenuItem.separator(),
        MenuItem(key: 'exit_app', label: 'Exit App'),
      ],
    );
    await trayManager.setContextMenu(menu);
  }

  Future<void> loadSettings() async {
    snapshotInterval = await service.getCaptureInterval();
    currentCapture = await service.getLastCaptureId() ?? -1;

    print(snapshotInterval);
    valueListenable.value = snapshotInterval;
  }

  Future<void> loadCaptures() async {
    await loadSettings();
    currentProjectCapture = currentCapture > -1
        ? await captureDB.getCaptureById(currentCapture)
        : null;
    captures = await captureDB.getAllCaptures();
    captureCheckBoxList = List.filled(captures.length, false);
    currentCaptureIndex = captures.indexWhere(
      (element) => element.id == currentCapture,
    );
    setState(() {});
    print("loaded captures");
  }

  @override
  void initState() {
    loadCaptures();

    super.initState();
    trayManager.addListener(this);
    _handleTrayIcon().whenComplete(() {
      setState(() {});
    });
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000),
    );
  }

  @override
  void dispose() {
    trayManager.removeListener(this);

    super.dispose();
  }

  void startCaptureSession() async {
    closeSettings();
    if (currentProjectCapture == null) {
      await createNewCapture(defaultCaptureName);
    }

    // rust.startCaptureSession(
    //   intervalList[snapshotInterval] ?? -1,
    //   currentProjectCapture!.directoryPath,
    // );
    _controller.repeat();
    setState(() {
      isRunning = true;
      status = "CaptureSession Running";
    });
    startAutoCapture();
  }

  void stopCaptureSession() {
    // rust.stopCaptureSession();
    stopAutoCapture();
    _controller.stop();
    setState(() {
      isRunning = false;
      status = "CaptureSession Stopped";
    });
  }

  String dateToString(int date) {
    return DateFormat(
      'MM/dd/yyyy',
    ).format(DateTime.fromMillisecondsSinceEpoch(date));
  }

  Future<void> createNewCapture(String name) async {
    if (name.isEmpty) return;

    // DateTime now = DateTime.now();
    // Format as 09/22/2024
    // String formattedDate = DateFormat('MM/dd/yyyy').format(now);

    // Format as September 22, 2024
    // String fullDate = DateFormat('MMMM dd, yyyy').format(now);
    name = await generateUniqueProjectName(name);

    String newDirectory = await createCaptureDirectory(name);
    int newID = await captureDB.createCapture(name, newDirectory, lastHash);
    captures.insert(0, (await captureDB.getCaptureById(newID))!);
    setState(() {
      _createCaptureController.clear();
      currentCaptureIndex = 0;
      currentProjectCapture = captures[0];
    });
    print("Created new capture");
  }

  void deleteCaptures() async {
    List<int> ids = [];
    for (int i = 0; i < selectedCaptures.length; i++) {
      deleteCaptureDirectory(captures[selectedCaptures[i]].directoryPath);
      int id = captures[selectedCaptures[i]].id;
      ids.add(id);
      await captureDB.deleteCaptureById(id);
    }

    captures.removeWhere((element) => ids.contains(element.id));
    setState(() {
      selectedCaptures = [];
    });
  }

  void moveToFrontByIndex<T>(List<T> list, int index) {
    if (index < 0 || index >= list.length) return;

    final item = list.removeAt(index);
    list.insert(0, item);
  }

  void updateCapture(String newName) async {
    if (newName == currentProjectCapture!.name) return;
    newName = await generateUniqueProjectName(newName);
    Capture updatedCapture = currentProjectCapture!;
    String newCaptureDirectory = await renameVerenaFolder(
      oldCaptureDirectory: updatedCapture.directoryPath,
      newName: newName,
    );

    updatedCapture.name = newName;
    updatedCapture.directoryPath = newCaptureDirectory;
    updatedCapture.dateUpdated = DateTime.now();

    if (currentCaptureIndex > -1) {
      captures[currentCaptureIndex] = updatedCapture;
    }
    moveToFrontByIndex(captures, currentCaptureIndex);
    currentCaptureIndex = 0;
    setState(() {});
    print("updated");
    await captureDB.updateCapture(updatedCapture.id, updatedCapture);
  }

  void deleteCapture(int id) async {
    captures.removeWhere((i) => i.id == id);
    await captureDB.deleteCaptureById(id);
    await service.setLastCaptureId(-1);
    await deleteCaptureDirectory(currentProjectCapture!.directoryPath);
    setState(() {
      if (currentProjectCapture!.id == id) {
        currentProjectCapture = null;
        currentCaptureIndex = -1;
      }
    });

    print("Deleted capture");
  }

  void closeSettings() async {
    setState(() {
      openSettings = false;
    });
    await windowManager.setSize(Size(windowWidth, 60));
  }

  Future<Directory> createVerenaFolder(String name) async {
    final baseDir = await getApplicationDocumentsDirectory();

    // /documents/verena/
    final verenaDir = Directory('${baseDir.path}/verena');

    if (!(await verenaDir.exists())) {
      await verenaDir.create(recursive: true);
    }

    // /documents/verena/<name>/
    final newFolder = Directory('${verenaDir.path}/$name');

    if (!(await newFolder.exists())) {
      await newFolder.create(recursive: true);
    }

    return newFolder;
  }

  Future<void> _queueCapture() async {
    if (isCapturing) return; // prevents overlap

    isCapturing = true;

    try {
      final path =
          "${currentProjectCapture!.directoryPath}/captures/capture_${DateTime.now().millisecondsSinceEpoch}.jpg";
      print("START capture ${DateTime.now()}");
      final CaptureResult result = await captureService.captureAsync(path);
      print("END capture ${DateTime.now()}");
      await Future.delayed(Duration(milliseconds: 50));
      print(result.windowTitle.split(" - ").last);
      // _handleResult(result);
    } finally {
      isCapturing = false;
    }
  }

  Future<void> startCaptureLoop() async {
    while (true) {
      final start = DateTime.now();

      await _queueCapture();

      final elapsed = DateTime.now().difference(start);

      final remaining = const Duration(seconds: 1) - elapsed;
      print(elapsed);
      if (remaining > Duration.zero) {
        await Future.delayed(remaining);
      }
      if (!isRunning) {
        break;
      }
    }
  }

  void startAutoCapture() {
    startCaptureLoop();
  }

  void stopAutoCapture() {
    isRunning = false;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(
        255,
        132,
        60,
        60,
      ).withValues(alpha: 0.0),
      body: SizedBox(
        width: windowWidth,
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  width: windowWidth,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isRunning
                        ? const Color.fromARGB(32, 255, 255, 255)
                        : const Color.fromARGB(255, 255, 255, 255),
                    borderRadius: BorderRadius.all(Radius.circular(5)),
                    border: Border.all(
                      color: const Color.fromARGB(255, 0, 0, 0),
                      width: 1,
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onPanStart: (_) => windowManager.startDragging(),
                          onTap: () {
                            setState(() {
                              closeSettings();
                            });
                          },
                          child: const SizedBox.expand(),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            margin: EdgeInsets.only(left: 5),

                            width: 20,
                            height: 30,
                            child: Stack(
                              alignment: AlignmentGeometry.center,
                              children: [
                                Icon(
                                  Icons.drag_indicator_outlined,
                                  color: Colors.black,
                                ),
                                Positioned.fill(
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.translucent,
                                    onPanStart: (_) =>
                                        windowManager.startDragging(),
                                    child: const SizedBox.expand(),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          minimizeButton(context),
                          exitButton(context),
                          VerticalDivider(
                            width: 0.8,
                            indent: 4,
                            endIndent: 4,
                            color: Colors.black,
                          ),
                          processCaptureButton(context),
                          settingsButton(context),
                          beginCaptureButton(context),
                        ],
                      ),
                    ],
                  ),
                ),

                openSettings
                    ? Container(
                        margin: EdgeInsets.only(top: 10),
                        height: 355,
                        width: windowWidth,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: const Color.fromARGB(255, 0, 0, 0),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              alignment: Alignment.centerLeft,
                              margin: EdgeInsets.all(5),
                              padding: EdgeInsets.symmetric(horizontal: 5),
                              height: 25,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Listener(
                                onPointerSignal: (event) {
                                  if (event is PointerScrollEvent) {
                                    _scrollController.animateTo(
                                      _scrollController.offset +
                                          event.scrollDelta.dy,
                                      duration: const Duration(
                                        milliseconds: 100,
                                      ),
                                      curve: Curves.easeOut,
                                    );
                                  }
                                },
                                child: SingleChildScrollView(
                                  controller: _scrollController,
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      Text(
                                        currentProjectCapture != null
                                            ? currentProjectCapture!.name
                                            : "",
                                        style: GoogleFonts.montserrat(
                                          textStyle: TextStyle(
                                            color: const Color.fromARGB(
                                              255,
                                              255,
                                              255,
                                              255,
                                            ),
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            intervalDropdownButton(context),
                            Divider(
                              indent: 10,
                              endIndent: 10,
                              color: Colors.black,
                              thickness: 0.6,
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Container(
                                  width: 25,
                                  height: 25,
                                  alignment: Alignment.centerRight,
                                  child: RawMaterialButton(
                                    shape: CircleBorder(),
                                    onPressed: () {},
                                    padding: EdgeInsetsGeometry.all(2),
                                    fillColor: const Color.fromARGB(
                                      255,
                                      255,
                                      255,
                                      255,
                                    ),
                                    constraints: BoxConstraints(minWidth: 0.0),
                                    child: Icon(
                                      Icons.remove_red_eye_outlined,
                                      size: 18,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 5),
                                Container(
                                  width: 25,
                                  height: 25,
                                  alignment: Alignment.centerRight,
                                  child: RawMaterialButton(
                                    shape: CircleBorder(),
                                    onPressed: () {
                                      if (currentProjectCapture == null &&
                                          selectedCaptures.isEmpty) {
                                        return;
                                      }
                                      selectedCaptures.isEmpty
                                          ? deleteCapture(
                                              currentProjectCapture!.id,
                                            )
                                          : deleteCaptures();
                                    },
                                    padding: EdgeInsetsGeometry.all(2),
                                    fillColor: const Color.fromARGB(
                                      255,
                                      255,
                                      255,
                                      255,
                                    ),
                                    constraints: BoxConstraints(minWidth: 0.0),
                                    child: Icon(
                                      Icons.delete_outlined,
                                      size: 18,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8),
                              ],
                            ),
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.black),
                              ),
                              margin: EdgeInsets.all(7),
                              height: 175,
                              child: Scrollbar(
                                controller: _scrollController2,
                                thickness: 3,
                                radius: const Radius.circular(0),
                                thumbVisibility: true,
                                child: ScrollConfiguration(
                                  behavior: const ScrollBehavior().copyWith(
                                    scrollbars: false,
                                  ),
                                  child: ListView.builder(
                                    itemCount: captures.length,
                                    controller: _scrollController2,
                                    itemBuilder: (BuildContext context, int index) {
                                      return Container(
                                        alignment: Alignment.centerLeft,
                                        height: 23,
                                        width: windowWidth - 30,

                                        child: SizedBox(
                                          width: double.infinity,
                                          child: TapRegion(
                                            onTapOutside: (event) {
                                              if (currentCaptureIndex !=
                                                  index) {
                                                return;
                                              }

                                              setState(() {
                                                editingCaptureName = false;
                                              });
                                            },
                                            child: TextButton(
                                              onLongPress: () async {
                                                currentCaptureIndex = index;
                                                currentProjectCapture =
                                                    captures[index];

                                                _captureEditFocusNode
                                                    .requestFocus();
                                                setState(() {
                                                  _captureEditController.text =
                                                      captures[index].name;
                                                  editingCaptureName = true;
                                                });
                                                await service.setLastCaptureId(
                                                  currentProjectCapture!.id,
                                                );
                                              },
                                              onPressed: () async {
                                                print(editingCaptureName);
                                                if (editingCaptureName) return;
                                                if (HardwareKeyboard
                                                    .instance
                                                    .isShiftPressed) {
                                                  if (currentCaptureIndex !=
                                                      -1) {
                                                    selectedCaptures.add(
                                                      currentCaptureIndex,
                                                    );
                                                    currentCaptureIndex = -1;
                                                    currentProjectCapture =
                                                        null;
                                                    await service
                                                        .setLastCaptureId(-1);
                                                  }

                                                  if (selectedCaptures.contains(
                                                    index,
                                                  )) {
                                                    selectedCaptures.remove(
                                                      index,
                                                    );
                                                  } else {
                                                    selectedCaptures.add(index);
                                                  }
                                                } else {
                                                  selectedCaptures = [];
                                                  currentCaptureIndex =
                                                      currentCaptureIndex ==
                                                          index
                                                      ? -1
                                                      : index;
                                                  if (currentCaptureIndex ==
                                                      index) {
                                                    currentProjectCapture =
                                                        captures[index];

                                                    await service
                                                        .setLastCaptureId(
                                                          currentProjectCapture!
                                                              .id,
                                                        );
                                                  } else {
                                                    currentProjectCapture =
                                                        null;
                                                  }
                                                }
                                                setState(() {});
                                              },
                                              style: ButtonStyle(
                                                alignment: Alignment.centerLeft,
                                                backgroundColor:
                                                    WidgetStateProperty.resolveWith<
                                                      Color
                                                    >((
                                                      Set<WidgetState> states,
                                                    ) {
                                                      if (states.contains(
                                                            WidgetState.hovered,
                                                          ) ||
                                                          (currentCaptureIndex ==
                                                                  index ||
                                                              selectedCaptures
                                                                  .contains(
                                                                    index,
                                                                  ))) {
                                                        return const Color.fromARGB(
                                                          255,
                                                          255,
                                                          239,
                                                          232,
                                                        );
                                                      }
                                                      return Colors
                                                          .white; // null throus error in flutter 2.2+.
                                                    }),
                                                textStyle:
                                                    WidgetStatePropertyAll(
                                                      TextStyle(
                                                        color: Colors.black,
                                                      ),
                                                    ),
                                                shape: WidgetStatePropertyAll(
                                                  ContinuousRectangleBorder(),
                                                ),
                                              ),
                                              child:
                                                  editingCaptureName &&
                                                      currentCaptureIndex ==
                                                          index
                                                  ? Container(
                                                      child: TextField(
                                                        onSubmitted:
                                                            (value) async {
                                                              editingCaptureName =
                                                                  false;
                                                              setState(() {});
                                                              updateCapture(
                                                                value,
                                                              );
                                                            },
                                                        textAlignVertical:
                                                            TextAlignVertical
                                                                .center,
                                                        focusNode:
                                                            _captureEditFocusNode,
                                                        cursorColor:
                                                            Colors.black,
                                                        style:
                                                            GoogleFonts.montserrat(
                                                              textStyle:
                                                                  TextStyle(
                                                                    fontSize:
                                                                        10,
                                                                  ),
                                                            ),

                                                        decoration: InputDecoration(
                                                          enabledBorder: OutlineInputBorder(
                                                            gapPadding: 0,
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  3.0,
                                                                ),
                                                            borderSide: BorderSide(
                                                              color: Colors
                                                                  .transparent,
                                                              width: 0.0,
                                                            ),
                                                          ),
                                                          focusedBorder: OutlineInputBorder(
                                                            gapPadding: 0,
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  5.0,
                                                                ),
                                                            borderSide: BorderSide(
                                                              color: Colors
                                                                  .transparent,
                                                              width: 0.0,
                                                            ),
                                                          ),
                                                          border: OutlineInputBorder(
                                                            gapPadding: 0,
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  10.0,
                                                                ),
                                                          ),
                                                          contentPadding:
                                                              EdgeInsets.zero,
                                                          suffixIcon: InkWell(
                                                            onTap: () async {
                                                              editingCaptureName =
                                                                  false;
                                                              setState(() {});
                                                              updateCapture(
                                                                _captureEditController
                                                                    .text,
                                                              );
                                                            },
                                                            child: Icon(
                                                              Icons
                                                                  .edit_outlined,
                                                              color:
                                                                  Colors.black,
                                                              size: 10,
                                                            ),
                                                          ),
                                                        ),
                                                        controller:
                                                            _captureEditController,
                                                      ),
                                                    )
                                                  : Text(
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      captures[index].name,
                                                      style:
                                                          GoogleFonts.montserrat(
                                                            textStyle:
                                                                TextStyle(
                                                                  color: Colors
                                                                      .black,
                                                                  fontSize: 10,
                                                                ),
                                                          ),
                                                    ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.only(
                                left: 7,
                                right: 7,
                                top: 5,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      height: 40,
                                      child: TextField(
                                        onSubmitted: (String value) async {
                                          await createNewCapture(value);
                                        },
                                        controller: _createCaptureController,
                                        cursorColor: Colors.black,
                                        style: GoogleFonts.montserrat(
                                          textStyle: TextStyle(fontSize: 10),
                                        ),
                                        decoration: InputDecoration(
                                          suffixIcon: InkWell(
                                            onTap: () async {
                                              await createNewCapture(
                                                _createCaptureController.text,
                                              );
                                            },
                                            child: Icon(
                                              Icons.add,
                                              color: Colors.black,
                                              size: 10,
                                            ),
                                          ),
                                          hintText: "New capture",
                                          contentPadding: EdgeInsets.all(5),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              3.0,
                                            ),
                                            borderSide: BorderSide(
                                              color: Colors.grey,
                                              width: 0.0,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              5.0,
                                            ),
                                            borderSide: BorderSide(
                                              color: Colors.grey,
                                              width: 0.0,
                                            ),
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              10.0,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    : SizedBox(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget exitButton(BuildContext context) {
    return Opacity(
      opacity: isRunning ? 0.3 : 1,
      child: Tooltip(
        textStyle: GoogleFonts.lato(
          textStyle: TextStyle(color: Colors.black, fontSize: 11),
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black),
          borderRadius: BorderRadius.circular(5),
        ),
        padding: EdgeInsets.symmetric(vertical: 3, horizontal: 5),
        verticalOffset: 16,
        waitDuration: Duration(milliseconds: 600),
        exitDuration: Duration(milliseconds: 200),
        message: 'Exit',
        child: Container(
          width: 25,
          height: 25,
          alignment: Alignment.centerRight,
          child: RawMaterialButton(
            shape: CircleBorder(),
            onPressed: () async {
              windowManager.close();
            },
            padding: EdgeInsetsGeometry.all(2),
            fillColor: const Color.fromARGB(255, 255, 255, 255),
            constraints: BoxConstraints(minWidth: 0.0),
            child: Image.asset('assets/close.png'),
          ),
        ),
      ),
    );
  }

  Widget minimizeButton(BuildContext context) {
    return Opacity(
      opacity: isRunning ? 0.3 : 1,
      child: Tooltip(
        textStyle: GoogleFonts.lato(
          textStyle: TextStyle(color: Colors.black, fontSize: 11),
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black),
          borderRadius: BorderRadius.circular(5),
        ),
        padding: EdgeInsets.symmetric(vertical: 3, horizontal: 5),
        verticalOffset: 16,
        waitDuration: Duration(milliseconds: 600),
        exitDuration: Duration(milliseconds: 200),
        message: 'Minimize',
        child: Container(
          width: 25,
          height: 25,
          alignment: Alignment.centerRight,
          child: RawMaterialButton(
            shape: CircleBorder(),
            onPressed: () async {
              setState(() {
                closeSettings();
              });
              windowManager.hide();
            },
            padding: EdgeInsetsGeometry.all(2),
            fillColor: const Color.fromARGB(255, 255, 255, 255),
            constraints: BoxConstraints(minWidth: 0.0),
            child: Image.asset('assets/minimize.png'),
          ),
        ),
      ),
    );
  }

  Widget beginCaptureButton(BuildContext context) {
    return Tooltip(
      textStyle: GoogleFonts.lato(
        textStyle: TextStyle(color: Colors.black, fontSize: 11),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black),
        borderRadius: BorderRadius.circular(5),
      ),
      padding: EdgeInsets.symmetric(vertical: 3, horizontal: 5),
      verticalOffset: 16,
      waitDuration: Duration(milliseconds: 600),
      exitDuration: Duration(milliseconds: 200),
      message: currentProjectCapture == null
          ? 'Create and start new capture'
          : "Start capture for ${currentProjectCapture!.name}",
      child: Container(
        width: 25,
        height: 25,
        margin: EdgeInsets.only(right: 10),
        child: !isRunning
            ? RawMaterialButton(
                onPressed: isRunning ? null : startCaptureSession,
                fillColor: Colors.white,
                constraints: BoxConstraints(minWidth: 0.0),
                shape: CircleBorder(),
                child: RotationTransition(
                  turns: Tween(begin: 0.0, end: 1.0).animate(_controller),
                  child: Image.asset('assets/play_new.png'),
                ),
              )
            : RawMaterialButton(
                onPressed: isRunning ? stopCaptureSession : null,
                fillColor: const Color.fromARGB(255, 255, 255, 255),
                constraints: BoxConstraints(minWidth: 0.0),
                shape: CircleBorder(),
                child: RotationTransition(
                  turns: Tween(begin: 0.0, end: 1.0).animate(_controller),
                  child: Image.asset('assets/logo_large3.png'),
                ),
              ),
      ),
    );
  }

  Widget settingsButton(BuildContext context) {
    return Opacity(
      opacity: isRunning ? 0.3 : 1,
      child: Tooltip(
        textStyle: GoogleFonts.lato(
          textStyle: TextStyle(color: Colors.black, fontSize: 11),
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black),
          borderRadius: BorderRadius.circular(5),
        ),
        padding: EdgeInsets.symmetric(vertical: 3, horizontal: 5),
        verticalOffset: 16,
        waitDuration: Duration(milliseconds: 600),
        exitDuration: Duration(milliseconds: 200),
        message: 'Settings',
        child: Container(
          width: 25,
          height: 25,
          alignment: Alignment.centerRight,
          child: RawMaterialButton(
            shape: CircleBorder(),
            onPressed: () async {
              if (openSettings) {
                ignoreNextOutsideTap = true;
              }
              stopCaptureSession();
              setState(() {
                openSettings = !openSettings;
              });
              openSettings
                  ? await windowManager.setSize(Size(windowWidth, 400))
                  : await windowManager.setSize(Size(windowWidth, 60));
            },
            padding: EdgeInsetsGeometry.all(2),
            fillColor: openSettings
                ? Colors.black
                : const Color.fromARGB(255, 255, 255, 255),
            constraints: BoxConstraints(minWidth: 0.0),
            child: Image.asset(
              openSettings
                  ? 'assets/settings2_inverse.png'
                  : 'assets/settings2.png',
            ),
          ),
        ),
      ),
    );
  }

  Widget processCaptureButton(BuildContext context) {
    return Opacity(
      opacity: isRunning ? 0.3 : 1,
      child: Tooltip(
        textStyle: GoogleFonts.lato(
          textStyle: TextStyle(color: Colors.black, fontSize: 11),
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black),
          borderRadius: BorderRadius.circular(5),
        ),
        padding: EdgeInsets.symmetric(vertical: 3, horizontal: 5),
        verticalOffset: 16,
        waitDuration: Duration(milliseconds: 600),
        exitDuration: Duration(milliseconds: 200),
        message: 'Process capture',
        child: Container(
          width: 25,
          height: 25,
          alignment: Alignment.centerRight,
          child: RawMaterialButton(
            shape: CircleBorder(),
            onPressed: () async {
              setState(() {
                stopCaptureSession();

                closeSettings();
              });
            },
            padding: EdgeInsetsGeometry.all(2),
            fillColor: const Color.fromARGB(255, 255, 255, 255),
            constraints: BoxConstraints(minWidth: 0.0),
            child: Image.asset('assets/process.png'),
          ),
        ),
      ),
    );
  }

  Widget intervalDropdownButton(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DropdownButton2<String>(
        isExpanded: true,
        items: intervalList.keys
            .toList()
            .map(
              (String item) => DropdownItem<String>(
                value: item,
                height: 40,
                child: Text(
                  item,
                  style: GoogleFonts.montserrat(
                    textStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color.fromARGB(255, 0, 0, 0),
                    ),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
        valueListenable: valueListenable,
        onChanged: (value) {
          valueListenable.value = value;
          service.setCaptureInterval(value ?? "1 minute");
        },
        buttonStyleData: ButtonStyleData(
          height: 35,
          width: windowWidth,
          padding: const EdgeInsets.only(left: 14, right: 14, top: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: const Color.fromARGB(255, 255, 255, 255),
          ),
        ),
        iconStyleData: const IconStyleData(
          icon: Icon(Icons.arrow_forward_ios_outlined),
          iconSize: 10,
          iconEnabledColor: Color.fromARGB(255, 0, 0, 0),
          iconDisabledColor: Colors.grey,
        ),
        dropdownStyleData: DropdownStyleData(
          elevation: 0,
          maxHeight: 182,
          width: windowWidth - 4,
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 255, 255, 255),
          ),
          offset: const Offset(0, 0),
          scrollbarTheme: ScrollbarThemeData(
            radius: const Radius.circular(40),
            thickness: WidgetStateProperty.all(4),
            thumbVisibility: WidgetStateProperty.all(false),
            trackVisibility: WidgetStateProperty.all(false),
          ),
        ),
        menuItemStyleData: const MenuItemStyleData(
          padding: EdgeInsets.only(left: 14, right: 14),
        ),
      ),
    );
  }

  @override
  void onTrayIconMouseDown() {
    // do something, for example pop up the menu
    windowManager.show();
    windowManager.focus();
    // trayManager.popUpContextMenu();
  }

  @override
  void onTrayIconRightMouseDown() {
    // do something
  }

  @override
  void onTrayIconRightMouseUp() {
    // do something
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'show_window') {
      windowManager.show();
      windowManager.focus();
      // do something
    } else if (menuItem.key == 'exit_app') {
      trayManager.destroy();
      windowManager.destroy();
    }
  }
}
