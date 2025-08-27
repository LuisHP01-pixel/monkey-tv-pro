// lib/main.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'player_screen.dart';
import 'search_screen.dart';
import 'favorites_screen.dart';
import 'web_player_screen.dart'; // <-- AÑADIR ESTA IMPORTACIÓN

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Monkey TV Pro',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: ColorScheme.fromSwatch().copyWith(
          secondary: Colors.orange,
          primary: Colors.orange,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          elevation: 2,
        ),
      ),
      home: const HomeScreen(),
      routes: {
        '/search': (context) => const SearchScreen(),
        '/favorites': (context) => const FavoritesScreen(),
      },
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List allCanales = [];
  List<String> favoriteCanales = [];
  bool isLoading = true;
  String? errorMessage;
  final ScrollController _scrollController = ScrollController();
  final Map<String, List> _canalesPorCategoria = {};

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    fetchCanales();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      favoriteCanales = prefs.getStringList('favorites') ?? [];
    });
  }

  Future<void> _toggleFavorite(String channelId) async {
    final prefs = await SharedPreferences.getInstance();
    final currentFavorites = prefs.getStringList('favorites') ?? [];
    
    if (currentFavorites.contains(channelId)) {
      currentFavorites.remove(channelId);
    } else {
      currentFavorites.add(channelId);
    }
    await prefs.setStringList('favorites', currentFavorites);
    
    if (!mounted) return;
    setState(() {
      favoriteCanales = currentFavorites;
      for (var canal in allCanales) {
        if (canal['id'].toString() == channelId) {
          canal['isFavorite'] = !canal['isFavorite'];
        }
      }
    });
  }

  Future<void> fetchCanales() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final url = Uri.parse('https://monkeytvpro.com/api.php');
      final response = await http.get(url).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cachedCanales', json.encode(data));
        await prefs.setInt('lastCacheTime', DateTime.now().millisecondsSinceEpoch);

        final List canalesJuntos = [];
        _canalesPorCategoria.clear();

        data.forEach((categoria, listaDeCanales) {
          _canalesPorCategoria[categoria] = List.from(listaDeCanales);
          for (var canal in listaDeCanales) {
            canalesJuntos.add({
              ...canal,
              'categoria': categoria,
              'isFavorite': favoriteCanales.contains(canal['id'].toString())
            });
          }
        });
        
        if (!mounted) return;
        setState(() {
          allCanales = canalesJuntos;
          isLoading = false;
        });
      } else {
        throw Exception('Error en el servidor: Código ${response.statusCode}');
      }
    } catch (e) {
      await _loadCachedData();
      if (!mounted) return;
      setState(() {
        errorMessage = "No se pudo conectar. Mostrando datos guardados.";
        isLoading = false;
      });
    }
  }

  Future<void> _loadCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString('cachedCanales');
      
      if (cachedData != null) {
        final Map<String, dynamic> data = json.decode(cachedData);
        final List canalesJuntos = [];
        _canalesPorCategoria.clear();

        data.forEach((categoria, listaDeCanales) {
          _canalesPorCategoria[categoria] = List.from(listaDeCanales);
          for (var canal in listaDeCanales) {
            canalesJuntos.add({
              ...canal,
              'categoria': categoria,
              'isFavorite': favoriteCanales.contains(canal['id'].toString())
            });
          }
        });
        
        if (!mounted) return;
        setState(() {
          allCanales = canalesJuntos;
        });
      }
    } catch (e) {
      // Manejar error de caché
    }
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(
            errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: fetchCanales,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.orange),
          SizedBox(height: 16),
          Text('Cargando canales...'),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.tv_off, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('No hay canales disponibles'),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: fetchCanales,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Recargar'),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection(String category, List channels) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            category,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
          ),
        ),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: channels.length,
            itemBuilder: (context, index) {
              final canal = channels[index];
              return _buildChannelCard(canal, 160, 120);
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // --- **** AQUÍ ESTÁ LA LÓGICA MODIFICADA **** ---
  Widget _buildChannelCard(Map<String, dynamic> canal, double width, double height) {
    bool isFav = favoriteCanales.contains(canal['id'].toString());
    return SizedBox(
      width: width,
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          onTap: () {
            final String url = canal['url'];

            // Decidimos qué reproductor abrir basado en la URL
            if (url.contains('appmonkeytvpro.x10.mx/ultimate/player.php')) {
              // Es una URL para el reproductor web
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => WebPlayerScreen(streamUrl: url),
                ),
              );
            } else {
              // Es una URL directa para el reproductor nativo
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PlayerScreen(
                    streamUrl: url,
                    channelName: canal['name'],
                    channelLogo: canal['logo'],
                    channelId: canal['id'].toString(),
                  ),
                ),
              );
            }
          },
          onLongPress: () => _toggleFavorite(canal['id'].toString()),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Image.network(
                        canal['logo'],
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.tv, size: 40, color: Colors.grey);
                        },
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(
                      canal['name'],
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
              if (isFav)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Icon(Icons.favorite, color: Colors.red.withOpacity(0.8), size: 20),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryView() {
    return ListView(
      controller: _scrollController,
      children: [
        ..._canalesPorCategoria.entries.map((entry) {
          return _buildCategorySection(entry.key, entry.value);
        }).toList(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monkey TV Pro'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.pushNamed(context, '/search'),
          ),
          IconButton(
            icon: const Icon(Icons.favorite),
            onPressed: () => Navigator.pushNamed(context, '/favorites'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchCanales,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: fetchCanales,
        color: Colors.orange,
        child: isLoading
            ? _buildLoadingWidget()
            : errorMessage != null
                ? _buildErrorWidget()
                : allCanales.isEmpty
                    ? _buildEmptyWidget()
                    : _buildCategoryView(),
      ),
    );
  }
}