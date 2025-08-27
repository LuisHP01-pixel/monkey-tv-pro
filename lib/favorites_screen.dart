// lib/favorites_screen.dart

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'player_screen.dart';
import 'web_player_screen.dart'; // <-- AÑADIR ESTA IMPORTACIÓN

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List _favoriteCanales = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favorites = prefs.getStringList('favorites') ?? [];
      final cachedData = prefs.getString('cachedCanales');
      
      if (cachedData != null) {
        final Map<String, dynamic> data = json.decode(cachedData);
        final List allCanales = [];
        
        data.forEach((categoria, listaDeCanales) {
          for (var canal in listaDeCanales) {
            allCanales.add({
              ...canal,
              'categoria': categoria,
            });
          }
        });

        final favoriteChannels = allCanales.where((canal) {
          return favorites.contains(canal['id'].toString());
        }).toList();

        setState(() {
          _favoriteCanales = favoriteChannels;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _removeFavorite(String channelId) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = prefs.getStringList('favorites') ?? [];
    favorites.remove(channelId);
    await prefs.setStringList('favorites', favorites);
    
    setState(() {
      _favoriteCanales.removeWhere((canal) => canal['id'].toString() == channelId);
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Removido de favoritos')),
    );
  }

  // --- **** AQUÍ ESTÁ LA LÓGICA MODIFICADA **** ---
  Widget _buildFavoriteTile(Map<String, dynamic> canal) {
    return Dismissible(
      key: Key(canal['id'].toString()),
      background: Container(color: Colors.red),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) => _removeFavorite(canal['id'].toString()),
      child: ListTile(
        leading: Image.network(
          canal['logo'],
          width: 50,
          height: 50,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(Icons.tv, size: 40);
          },
        ),
        title: Text(canal['name']),
        subtitle: Text(canal['categoria']),
        trailing: IconButton(
          icon: const Icon(Icons.favorite, color: Colors.red),
          onPressed: () => _removeFavorite(canal['id'].toString()),
        ),
        onTap: () {
          final String url = canal['url'];

          // Decidimos qué reproductor abrir basado en la URL
          if (url.contains('appmonkeytvpro.x10.mx/ultimate/player.php')) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => WebPlayerScreen(streamUrl: url),
              ),
            );
          } else {
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
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_border, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('No tienes canales favoritos'),
          SizedBox(height: 8),
          Text('Mantén presionado un canal para agregarlo', 
               style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Favoritos'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _favoriteCanales.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  itemCount: _favoriteCanales.length,
                  itemBuilder: (context, index) {
                    return _buildFavoriteTile(_favoriteCanales[index]);
                  },
                ),
    );
  }
}