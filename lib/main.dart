import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

// Вставьте сюда свой партнёрский API-ключ Transak (https://transak.com)
const transakApiKey = 'ВАШ_API_KEY';

void main() => runApp(const CryptoApp());

class CryptoApp extends StatelessWidget {
  const CryptoApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Crypto Invest',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(useMaterial3: true),
        home: const CoinListPage(),
      );
}

class Coin {
  final String name, symbol, image;
  final double price, change;
  Coin(this.name, this.symbol, this.image, this.price, this.change);

  factory Coin.fromJson(Map<String, dynamic> j) => Coin(
        j['name'],
        (j['symbol'] as String).toUpperCase(),
        j['image'],
        (j['current_price'] ?? 0).toDouble(),
        (j['price_change_percentage_24h'] ?? 0).toDouble(),
      );
}

class CoinListPage extends StatefulWidget {
  const CoinListPage({super.key});
  @override
  State<CoinListPage> createState() => _CoinListPageState();
}

class _CoinListPageState extends State<CoinListPage> {
  late Future<List<Coin>> coins = load();
  String query = '';

  Future<List<Coin>> load() async {
    final r = await http.get(Uri.parse(
        'https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&order=market_cap_desc&per_page=100&page=1'));
    if (r.statusCode != 200) throw Exception('Ошибка загрузки');
    return (jsonDecode(r.body) as List).map((e) => Coin.fromJson(e)).toList();
  }

  Future<void> buy(Coin c) async {
    final url = Uri.https('global.transak.com', '/', {
      'apiKey': transakApiKey,
      'cryptoCurrencyCode': c.symbol,
      'fiatCurrency': 'USD',
    });
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crypto Invest')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Поиск монеты',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => query = v.toLowerCase()),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Coin>>(
            future: coins,
            builder: (context, s) {
              if (s.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (s.hasError) {
                return Center(
                  child: ElevatedButton(
                    onPressed: () => setState(() => coins = load()),
                    child: const Text('Повторить'),
                  ),
                );
              }
              final list = s.data!
                  .where((c) =>
                      c.name.toLowerCase().contains(query) ||
                      c.symbol.toLowerCase().contains(query))
                  .toList();
              return RefreshIndicator(
                onRefresh: () async {
                  setState(() => coins = load());
                  await coins;
                },
                child: ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final c = list[i];
                    final up = c.change >= 0;
                    return ListTile(
                      leading: Image.network(c.image, width: 36, height: 36),
                      title: Text(c.name),
                      subtitle: Text(
                        '\$${c.price} • ${up ? '+' : ''}${c.change.toStringAsFixed(2)}%',
                        style: TextStyle(
                            color: up ? Colors.greenAccent : Colors.redAccent),
                      ),
                      trailing: FilledButton(
                        onPressed: () => buy(c),
                        child: const Text('Купить'),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}
