// ignore_for_file: avoid_print, depend_on_referenced_packages

import 'package:supabase/supabase.dart';
import 'dart:io';

void main() async {
  const url = 'https://uqxoadxqcwidxqsfayem.supabase.co';
  const key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVxeG9hZHhxY3dpZHhxc2ZheWVtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg0NDUxODksImV4cCI6MjA4NDAyMTE4OX0.q9_RqSx4YfJxlblPS9fwrocx3HDH91ff1zJvPbVGI8w';

  final client = SupabaseClient(url, key);
  
  print('RealtimeClient type: ${client.realtime.runtimeType}');
  
  // Vamos registrar ouvintes para o status da conexão do socket
  client.realtime.onOpen(() {
    print('🔄 SOCKET STATUS: Open');
  });
  client.realtime.onClose((event) {
    print('🔄 SOCKET STATUS: Close. Event: $event');
  });
  client.realtime.onError((error) {
    print('🔄 SOCKET STATUS: Error: $error');
  });

  final channel = client.channel('public:entregas');
  
  channel.subscribe((status, [error]) {
    print('📺 CHANNEL STATUS: $status');
    if (error != null) {
      print('   Erro: $error');
    }
  });

  await Future.delayed(const Duration(seconds: 3));
  exit(0);
}
