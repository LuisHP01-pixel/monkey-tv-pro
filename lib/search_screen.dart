// lib/search_screen.dart

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'player_screen.dart';
import 'web_player_screen.dart'; // <-- AÑADIR ESTA IMPORTACIÓN

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  List _allCanales = [];
  List _filteredCanales = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCachedData();
  }

  Future<void> _loadCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString('cachedCanales');
      
      if (cachedData != null) {
        final Map<String, dynamic> data = json.decode(cachedData);
        final List canalesJuntos = [];
        
        data.forEach((categoria, listaDeCanales) {
          for (var canal in listaDeCanales) {
            canalesJuntos.add({
              ...canal,
              'categoria': categoria,
            });
          }
        });

        setState(() {
          _allCanales = canalesJuntos;
          _filteredCanales = canalesJuntos;
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

  void _searchChannels(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredCanales = _allCanales;
      });
      return;
    }

    final results = _allCanales.where((canal) {
      final name = canal['name'].toString().toLowerCase();
      final category = canal['categoria'].toString().toLowerCase();
      final searchLower = query.toLowerCase();
      
      return name.contains(searchLower) || category.contains(searchLower);
    }).toList();

    setState(() {
      _filteredCanales = results;
    });
  }

  // --- **** AQUÍ ESTÁ LA LÓGICA MODIFICADA **** ---
  Widget _buildChannelTile(Map<String, dynamic> canal) {
    return ListTile(
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
      trailing: const Icon(Icons.play_arrow),
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
    );
  }

  Widget _buildResults() {
    if (_filteredCanales.isEmpty) {
      return const Center(
        child: Text('No se encontraron resultados'),
      );
    }

    return ListView.builder(
      itemCount: _filteredCanales.length,
      itemBuilder: (context, index) {
        return _buildChannelTile(_filteredCanales[index]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: 'Buscar canales...',
            border: InputBorder.none,
          ),
          onChanged: _searchChannels,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              _searchController.clear();
              _searchChannels('');
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildResults(),
    );
  }
}