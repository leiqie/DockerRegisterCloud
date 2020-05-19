import 'dart:io';

import 'package:docker_register_cloud/component/DrcDialogs.dart';
import 'package:docker_register_cloud/model/GlobalModel.dart';
import 'package:docker_register_cloud/model/TransportModel.dart';
import 'package:docker_register_cloud/repository.dart';
import 'package:file_picker/file_picker.dart';
import 'package:filesize/filesize.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class DrcFileList extends StatefulWidget {
  final String repository;
  DrcFileList(this.repository);
  @override
  State<StatefulWidget> createState() {
    return DrcFileListState();
  }
}

class DrcFileListState extends State<DrcFileList>
    with TickerProviderStateMixin {
  String path = "/";
  List<FileItem> items;
  String repository = "";

  final repositoryController = TextEditingController();

  @override
  void dispose() {
    // Clean up the controller when the widget is removed from the
    // widget tree.
    repositoryController.dispose();
    super.dispose();
  }

  @override
  didChangeDependencies() async {
    super.didChangeDependencies();
    updateRepositoryEditing();
  }

  updateRepositoryEditing() {
    repositoryController.text = "${widget.repository}:${this.path}";
  }

  onRepositorySubmitted(String value) async {
    UIPlatform platform = Provider.of<UIPlatform>(context, listen: false);
    platform.setCurrentRepository(value.split(":")[0]);
  }

  onDownloadClick(FileItem item, String name, GlobalKey itemkey) async {
    UIPlatform platform = Provider.of<UIPlatform>(context, listen: false);
    TransportModel transport =
        Provider.of<TransportModel>(context, listen: false);
    if (transport.items.containsKey("${widget.repository}:${item.name}")) {
      if (transport.items["${widget.repository}:${item.name}"].state !=
          TransportStateType.COMPLETED) {
        Scaffold.of(context).showSnackBar(SnackBar(
          content: Text(
            "该文件已经在下载列表不可重复下载。",
            style: TextStyle(fontFamilyFallback: ['WenQuanYi Micro Hei']),
          ),
        ));
        return;
      } else {
        if (await DrcDialogs.showConfirm(
                "确认覆盖", "该文件已经在下载列表，是否覆盖下载？", context) !=
            true) {
          return;
        }
      }
    }
    try {
      await platform.download(
          widget.repository, item.digest, item.name, transport);
    } catch (err) {
      Scaffold.of(context).showSnackBar(SnackBar(
        content: Text("获取下载链接失败，推荐用本地客户端试试",
            style: TextStyle(fontFamilyFallback: ['WenQuanYi Micro Hei'])),
        action: SnackBarAction(
          label: "下载客户端",
          onPressed: () {
            launch("https://github.com/xausky/DockerRegisterCloud");
          },
        ),
      ));
    }
  }

  onRefreshClick() async {
    UIPlatform platform = Provider.of<UIPlatform>(context, listen: false);
    setState(() {
      items = null;
    });
    String username, password;
    while (true) {
      try {
        if(username != null && password != null){
          await platform.login(repository, username, password);
        }
        var value = await platform.items(widget.repository);
        setState(() {
          items = value;
        });
        break;
      } on PermissionDeniedException catch (_) {
        List<String> results =
            await DrcDialogs.showAuthority(repository, context);
        if (results == null) {
          setState(() {
            items = [];
          });
          break;
        }
        username = results[0];
        password = results[1];
      } catch (e) {
        print(e);
        setState(() {
          items = [];
        });
        break;
      }
    }
  }

  onUploadClick() async {
    File target = await FilePicker.getFile();
    print(target);
    if (target == null || !await target.exists()) {
      return;
    }
    UIPlatform platform = Provider.of<UIPlatform>(context, listen: false);
    TransportModel transport =
        Provider.of<TransportModel>(context, listen: false);
    String targetPath = target.path;
    if (Platform.isWindows) {
      targetPath = targetPath.replaceAll("\\", "/");
    }
    String name = this.path + targetPath.split("/").last;
    while (true) {
      try {
        await platform.upload(widget.repository, name, targetPath, transport);
        onRefreshClick();
        break;
      } on PermissionDeniedException catch (_) {
        List<String> results =
            await DrcDialogs.showAuthority(repository, context);
        if (results == null) {
          transport.removeItem("${widget.repository}:$name");
          break;
        }
        await platform.login(repository, results[0], results[1]);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.repository != this.repository && widget.repository != null) {
      this.repository = widget.repository;
      onRefreshClick();
    }
    if (widget.repository == null) {
      this.repository = "";
      items = [];
    }
    repositoryController.text = "${this.repository}:${this.path}";
    List<Widget> list = List();
    List<Widget> headers = List();
    List<Widget> toolbar = List();
    toolbar.add(Container(
      child: IconButton(
        iconSize: 32,
        color: Theme.of(context).primaryColor,
        icon: Icon(Icons.home),
        onPressed: () {
          setState(() {
            this.path = "/";
            updateRepositoryEditing();
          });
        },
      ),
    ));
    toolbar.add(Container(
      child: IconButton(
        iconSize: 32,
        color: Theme.of(context).primaryColor,
        icon: Icon(Icons.keyboard_arrow_up),
        onPressed: () {
          setState(() {
            int index = this.path.lastIndexOf("/", this.path.length - 2);
            if (index == -1) {
              this.path = "/";
            } else {
              this.path = this.path.substring(0, index + 1);
            }
          });
          updateRepositoryEditing();
        },
      ),
    ));
    if (!kIsWeb) {
      toolbar.add(Container(
        child: IconButton(
          iconSize: 32,
          color: Theme.of(context).primaryColor,
          icon: Icon(Icons.file_upload),
          onPressed: () {
            onUploadClick();
          },
        ),
      ));
      toolbar.add(Container(
        child: IconButton(
          iconSize: 32,
          color: Theme.of(context).primaryColor,
          icon: Icon(Icons.add_box),
          onPressed: () async {
            String name = await DrcDialogs.showInput("输入文件夹名称", context);
            if (name != null) {
              setState(() {
                items.add(FileItem(name: '$name/'));
              });
            }
          },
        ),
      ));
    }
    toolbar.add(Container(
      child: IconButton(
        iconSize: 32,
        color: Theme.of(context).primaryColor,
        icon: Icon(Icons.refresh),
        onPressed: () {
          onRefreshClick();
        },
      ),
    ));
    toolbar.add(Flexible(
        child: TextField(
      controller: repositoryController,
      style: TextStyle(
        fontSize: 16,
      ),
      decoration: InputDecoration(
          isDense: true, border: OutlineInputBorder(), labelText: '仓库地址'),
      onSubmitted: (value) => onRepositorySubmitted(value),
    )));
    headers.add(
      Container(
          margin: EdgeInsets.all(8),
          height: 46,
          child: Row(
            children: toolbar,
          )),
    );
    if (items == null) {
      headers.add(SizedBox(
        child: LinearProgressIndicator(),
        height: 4,
      ));
    } else {
      Set<String> dirs = Set();
      items.forEach((element) {
        String name = element.name;
        if (!name.startsWith("/")) {
          name = "/$name";
        }
        if (name.startsWith(path)) {
          name = name.substring(path.length);
          if (name.indexOf("/") != -1) {
            name = name.substring(0, name.indexOf("/"));
            if (dirs.add(name)) {
              list.add(
                InkWell(
                    onTap: () {
                      setState(() {
                        this.path = "$path$name/";
                        repositoryController.text =
                            "${widget.repository}:${this.path}";
                      });
                    },
                    child: FileItemView(
                      name: name,
                      directory: true,
                    )),
              );
            }
          }
        }
      });
      items.forEach((element) {
        Key itemkey = GlobalKey();
        String name = element.name;
        if (!name.startsWith("/")) {
          name = "/$name";
        }
        if (name.startsWith(path)) {
          name = name.substring(path.length);
          if (name.indexOf("/") == -1 && name.isNotEmpty) {
            list.add(
              InkWell(
                  onTap: () {
                    onDownloadClick(element, name, itemkey);
                  },
                  child: FileItemView(
                    key: itemkey,
                    name: name,
                    size: element.size,
                    digest: element.digest,
                    directory: false,
                    onDelete: () async {
                      if (await DrcDialogs.showConfirm(
                          "确认删除", "确定删除文件[$name]", context)) {
                        await context.read<UIPlatform>().remove(element.name);
                        setState(() {
                          items.remove(element);
                        });
                        Scaffold.of(context).showSnackBar(SnackBar(
                          content: Text("删除文件成功",
                              style: TextStyle(
                                  fontFamilyFallback: ['WenQuanYi Micro Hei'])),
                        ));
                      }
                    },
                  )),
            );
          }
        }
      });
    }

    headers.add(Expanded(
      child: ListView(
        children: list,
      ),
    ));
    return Column(
      mainAxisSize: MainAxisSize.max,
      children: headers,
    );
  }
}

class FileItemView extends StatefulWidget {
  final bool directory;
  final String name;
  final String digest;
  final int size;
  final Function onDelete;

  const FileItemView(
      {Key key,
      this.directory,
      this.name,
      this.size,
      this.digest,
      this.onDelete})
      : super(key: key);
  @override
  State<StatefulWidget> createState() {
    return FileItemViewState();
  }
}

class FileItemViewState extends State<FileItemView> {
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(8),
      child: Row(
        children: [
          Icon(
            widget.directory ? Icons.folder : Icons.insert_drive_file,
            size: 42,
            color: widget.directory
                ? Theme.of(context).primaryColor
                : Theme.of(context).primaryColorLight,
          ),
          Expanded(
            child: Column(
              children: [
                Container(
                  margin: EdgeInsets.all(4),
                  child: Text(
                    widget.name,
                    textAlign: TextAlign.left,
                  ),
                ),
                Container(
                  margin: EdgeInsets.all(4),
                  child: Text(widget.directory ? "-" : filesize(widget.size),
                      textAlign: TextAlign.left),
                )
              ],
              crossAxisAlignment: CrossAxisAlignment.start,
            ),
          ),
          widget.directory
              ? Column()
              : IconButton(
                  color: Theme.of(context).primaryColor,
                  icon: Icon(Icons.content_copy),
                  onPressed: () async {
                    UIPlatform global =
                        Provider.of<UIPlatform>(context, listen: false);
                    global.writeClipy(widget.name);
                    Scaffold.of(context).showSnackBar(SnackBar(
                      content: Text("复制文件名成功",
                          style: TextStyle(
                              fontFamilyFallback: ['WenQuanYi Micro Hei'])),
                    ));
                  },
                  tooltip: "复制文件名",
                ),
          widget.directory
              ? Column()
              : IconButton(
                  color: Theme.of(context).primaryColor,
                  icon: Icon(Icons.link),
                  onPressed: () async {
                    UIPlatform global =
                        Provider.of<UIPlatform>(context, listen: false);
                    global
                        .link(global.config.currentRepository, widget.digest)
                        .then((value) {
                      global.writeClipy(value);
                      Scaffold.of(context).showSnackBar(SnackBar(
                        content: Text("复制下载链接成功",
                            style: TextStyle(
                                fontFamilyFallback: ['WenQuanYi Micro Hei'])),
                      ));
                    }).catchError((err) {
                      Scaffold.of(context).showSnackBar(SnackBar(
                        content: Text("获取下载链接失败，推荐用本地客户端试试",
                            style: TextStyle(
                                fontFamilyFallback: ['WenQuanYi Micro Hei'])),
                        action: SnackBarAction(
                          label: "下载客户端",
                          onPressed: () {
                            launch(
                                "https://github.com/xausky/DockerRegisterCloud");
                          },
                        ),
                      ));
                    });
                  },
                  tooltip: "复制下载链接",
                ),
          widget.directory
              ? Column()
              : IconButton(
                  color: Theme.of(context).primaryColor,
                  icon: Icon(Icons.delete),
                  onPressed: widget.onDelete,
                  tooltip: "删除文件",
                ),
        ],
      ),
    );
  }
}
