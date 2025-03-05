import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io' show File, Directory;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'dart:html' as html;
import 'dart:typed_data';  // Import necesario para Uint8List

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool isDarkMode = true;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KORTEX - YouTube Downloader',
      debugShowCheckedModeBanner: false,
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.blue,
        colorScheme: ColorScheme.light(primary: Colors.blue),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: Colors.blue),
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.blue,
        colorScheme: ColorScheme.dark(primary: Colors.blue, secondary: Colors.blueAccent),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: Colors.blue),
        ),
      ),
      home: YouTubeDownloader(
        onThemeChanged: () {
          setState(() {
            isDarkMode = !isDarkMode;
          });
        },
      ),
    );
  }
}

class YouTubeDownloader extends StatefulWidget {
  final VoidCallback onThemeChanged;
  const YouTubeDownloader({Key? key, required this.onThemeChanged}) : super(key: key);

  @override
  _YouTubeDownloaderState createState() => _YouTubeDownloaderState();
}

class _YouTubeDownloaderState extends State<YouTubeDownloader> {
  final TextEditingController urlController = TextEditingController();
  String title = "";
  String thumbnailUrl = "";
  String description = "";
  String publishedDate = "";
  String selectedFormat = "MP3";
  final List<String> formats = ["MP3", "MP4"];
  bool isLoading = false;
  bool showFullDescription = false;

  // Cambia esta URL por la de tu servidor backend
  final String backendBaseUrl = "http://10.0.0.228:5000";

  Future<void> fetchVideoDetails() async {
    final url = urlController.text.trim();
    if (url.isEmpty) return;
    setState(() {
      isLoading = true;
    });
    try {
      final response = await http.get(Uri.parse('$backendBaseUrl/info?url=$url'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          title = data['title'] ?? "";
          thumbnailUrl = data['thumbnail'] ?? "";
          description = data['description'] ?? "";
          publishedDate = data['upload_date'] ?? "";
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al obtener detalles: ${response.body}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"))
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> downloadVideo() async {
    final url = urlController.text.trim();
    if (url.isEmpty) return;
    setState(() {
      isLoading = true;
    });
    try {
      final uri = Uri.parse('$backendBaseUrl/download');
      final request = http.Request('POST', uri)
        ..headers['Content-Type'] = 'application/json'
        ..body = json.encode({"url": url, "format": selectedFormat});
      final client = http.Client();
      final response = await client.send(request);
      if (response.statusCode == 200) {
        // Usar http.Response.fromStream para obtener los bytes completos
        final httpResponse = await http.Response.fromStream(response);
        final bytes = httpResponse.bodyBytes;
        final ext = selectedFormat.toUpperCase() == "MP3" ? "mp3" : "mp4";
        final safeTitle = title.trim().isEmpty
            ? "downloaded_video"
            : title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '');
        if (kIsWeb) {
          // En web: crear Blob a partir de bytes y disparar descarga
          final mimeType = selectedFormat.toUpperCase() == "MP3" ? "audio/mpeg" : "video/mp4";
          final blob = html.Blob([bytes], mimeType);
          final blobUrl = html.Url.createObjectUrlFromBlob(blob);
          final anchor = html.AnchorElement(href: blobUrl)
            ..setAttribute("download", "$safeTitle.$ext");
          anchor.click();
          html.Url.revokeObjectUrl(blobUrl);
          showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: Text("Descarga completada"),
                content: Text("El archivo se ha descargado exitosamente. Revise la carpeta de descargas de su navegador."),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text("OK"),
                  ),
                ],
              );
            },
          );
        } else {
          // En móvil/desktop: guardar el archivo y abrirlo
          Directory appDocDir = await getApplicationDocumentsDirectory();
          Directory downloadsDir = Directory("${appDocDir.path}/Descargas");
          if (!await downloadsDir.exists()) {
            await downloadsDir.create(recursive: true);
          }
          final filePath = "${downloadsDir.path}/$safeTitle.$ext";
          final file = File(filePath);
          await file.writeAsBytes(bytes);
          if (await file.exists()) {
            await OpenFile.open(filePath);
            showDialog(
              context: context,
              builder: (context) {
                return AlertDialog(
                  title: Text("Descarga completada"),
                  content: Text("El archivo se ha guardado en:\n$filePath"),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text("OK"),
                    ),
                  ],
                );
              },
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Error: Archivo no encontrado en $filePath")),
            );
          }
        }
      } else {
        final errorBody = await response.stream.bytesToString();
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error al descargar: $errorBody")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Widget _buildDescription() {
    final textWidget = Text(
      description,
      style: TextStyle(fontSize: 16),
      textAlign: TextAlign.justify,
      maxLines: showFullDescription ? null : 5,
      overflow: showFullDescription ? TextOverflow.visible : TextOverflow.ellipsis,
    );
    final showButton = description.split("\n").length > 5 || description.length > 200;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        textWidget,
        if (showButton)
          TextButton(
            onPressed: () {
              setState(() {
                showFullDescription = !showFullDescription;
              });
            },
            child: Text(showFullDescription ? "Ver menos" : "Ver más"),
          )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Definimos un estilo personalizado para los botones
    final ButtonStyle customButtonStyle = ElevatedButton.styleFrom(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text("KORTEX - YouTube Downloader"),
        actions: [
          IconButton(
            icon: Icon(Icons.brightness_6),
            onPressed: widget.onThemeChanged,
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: urlController,
                    decoration: InputDecoration(
                      labelText: "Enlace de YouTube",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.link),
                    ),
                  ),
                  SizedBox(height: 16),
                  // Botón "Obtener detalles" con estilo personalizado
                  ElevatedButton(
                    style: customButtonStyle,
                    onPressed: isLoading ? null : fetchVideoDetails,
                    child: Text("Obtener detalles"),
                  ),
                  SizedBox(height: 16),
                  if (isLoading) Center(child: CircularProgressIndicator()),
                  if (!isLoading && thumbnailUrl.isNotEmpty) ...[
                    Card(
                      elevation: 10, // Mayor elevación para más sombra
                      shadowColor: Colors.black45,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    thumbnailUrl,
                                    width: 100,
                                    height: 100,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    title,
                                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            Text("Publicado el: $publishedDate",
                                style: TextStyle(color: Colors.grey[600])),
                            SizedBox(height: 12),
                            _buildDescription(),
                            SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                DropdownButton<String>(
                                  value: selectedFormat,
                                  items: formats
                                      .map((format) => DropdownMenuItem<String>(
                                            value: format,
                                            child: Text(format),
                                          ))
                                      .toList(),
                                  onChanged: (newValue) {
                                    setState(() {
                                      selectedFormat = newValue!;
                                    });
                                  },
                                ),
                                // Botón "Descargar" con estilo personalizado
                                ElevatedButton(
                                  style: customButtonStyle,
                                  onPressed: isLoading ? null : downloadVideo,
                                  child: Text("Descargar"),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ]
                ],
              ),
            ),
          ),
          Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.primary,
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text(
              "© 2025 Keury Ramirez",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
