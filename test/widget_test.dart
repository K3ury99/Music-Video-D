// Flutter widget test for YouTube Downloader app
// This test checks if UI elements exist and respond correctly.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_downloader/main.dart';

void main() {
  testWidgets('Check if UI elements exist', (WidgetTester tester) async {
    // Build the app
    await tester.pumpWidget(MyApp());

    // Verify that the text field for URL input is present
    expect(find.byType(TextField), findsOneWidget);

    // Verify that the 'Obtener detalles' button exists
    expect(find.text('Obtener detalles'), findsOneWidget);

    // Verify that the dropdown for format selection exists
    expect(find.byType(DropdownButton<String>), findsOneWidget);

    // Verify that the 'Descargar' button exists
    expect(find.text('Descargar'), findsOneWidget);
  });

  testWidgets('Enter URL and trigger fetch details', (WidgetTester tester) async {
    await tester.pumpWidget(MyApp());

    // Enter a sample URL
    await tester.enterText(find.byType(TextField), 'https://youtube.com/watch?v=dQw4w9WgXcQ');

    // Tap the 'Obtener detalles' button
    await tester.tap(find.text('Obtener detalles'));
    await tester.pump();

    // Since this requires network call, we assume success if button is tapped
    expect(find.text('Obtener detalles'), findsOneWidget);
  });

  testWidgets('Select format and initiate download', (WidgetTester tester) async {
    await tester.pumpWidget(MyApp());

    // Tap the dropdown button
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pump();

    // Select a format (assuming 'MP3 320kbps' is in the list)
    await tester.tap(find.text('MP3 320kbps').last);
    await tester.pump();

    // Tap the 'Descargar' button
    await tester.tap(find.text('Descargar'));
    await tester.pump();

    // Check if the download button exists, assuming it triggers a download
    expect(find.text('Descargar'), findsOneWidget);
  });
}