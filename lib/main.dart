import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:io';
import 'dart:async';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ContactProvider(),
      child: const MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Contato App',
        home: ContactListScreen(),
      ),
    );
  }
}

class Contato {
  int? id;
  String nome;
  String numeroTelefone;
  String caminhoFoto;

  Contato({
    this.id,
    required this.nome,
    required this.numeroTelefone,
    required this.caminhoFoto,
  });

  Contato copiar({
    int? id,
    String? nome,
    String? numeroTelefone,
    String? caminhoFoto,
  }) {
    return Contato(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      numeroTelefone: numeroTelefone ?? this.numeroTelefone,
      caminhoFoto: caminhoFoto ?? this.caminhoFoto,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'numeroTelefone': numeroTelefone,
      'caminhoFoto': caminhoFoto,
    };
  }
}

class DatabaseHelper {
  final String tablenome = 'contacts';
  late Database _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database;
    }

    _database = await initializeDatabase();
    return _database;
  }

  Future<Database> initializeDatabase() async {
    final path = await getDatabasesPath();
    _database = await openDatabase(
      '$path/contacts.db',
      version: 1,
      onCreate: (db, version) {
        db.execute('''
          CREATE TABLE $tablenome(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nome TEXT,
            numeroTelefone TEXT,
            caminhoFoto TEXT
          )
        ''');
      },
    );

    return _database;
  }

  Future<int> colocarContato(Contato contact) async {
    await initializeDatabase();
    return await _database.insert(tablenome, contact.toMap());
  }

  Future<List<Contato>> getContacts() async {
    await initializeDatabase();
    final List<Map<String, dynamic>> maps = await _database.query(tablenome);
    return List.generate(maps.length, (i) {
      return Contato(
        id: maps[i]['id'],
        nome: maps[i]['name'],
        numeroTelefone: maps[i]['phoneNumber'],
        caminhoFoto: maps[i]['photoPath'],
      );
    });
  }
}

class ContactProvider with ChangeNotifier {
  List<Contato> _contacts = [];
  List<Contato> get contacts => _contacts;

  Future<void> addContact(Contato contact) async {
    final dbHelper = DatabaseHelper();
    final newContactId =
        await dbHelper.colocarContato(contact.copiar(id: null));
    final updatedContacts = await dbHelper.getContacts();
    _contacts = updatedContacts;
    notifyListeners();
  }

  Future<void> carregarContato() async {
    final dbHelper = DatabaseHelper();
    final loadedContacts = await dbHelper.getContacts();
    _contacts = loadedContacts;
    notifyListeners();
  }
}

class ContactListScreen extends StatefulWidget {
  const ContactListScreen({super.key});

  @override
  _ContactListScreenState createState() => _ContactListScreenState();
}

class _ContactListScreenState extends State<ContactListScreen> {
  @override
  void initState() {
    super.initState();
    Provider.of<ContactProvider>(context, listen: false).carregarContato();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lista de Contatos'),
      ),
      body: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => AddContactScreen()));
                },
                child: const Text('Adicionar Contato'),
              ),
              const Expanded(
                child: ContactListView(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ContactListView extends StatelessWidget {
  const ContactListView({super.key});

  @override
  Widget build(BuildContext context) {
    final contacts = Provider.of<ContactProvider>(context).contacts;
    return ListView.builder(
      itemCount: contacts.length,
      itemBuilder: (context, index) {
        final contact = contacts[index];
        return ListTile(
          leading: Image.file(File(contact.caminhoFoto)),
          title: Text(contact.nome),
          subtitle: Text(contact.numeroTelefone),
        );
      },
    );
  }
}

class AddContactScreen extends StatefulWidget {
  const AddContactScreen({super.key});

  @override
  _AddContactScreenState createState() => _AddContactScreenState();
}

class _AddContactScreenState extends State<AddContactScreen> {
  final TextEditingController nomeController = TextEditingController();
  final TextEditingController numeroTelefoneController =
      TextEditingController();
  File? _image;

  Future<void> getImage() async {
    final image = await ImagePicker().getImage(source: ImageSource.camera);

    if (image != null) {
      final appDir = await getApplicationDocumentsDirectory();
      final filenome = 'contact_${DateTime.now()}.png';
      final savedImage =
          await File(image.path).copy('${appDir.path}/$filenome');
      setState(() {
        _image = savedImage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Adicionar Contato'),
      ),
      body: SingleChildScrollView(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 50),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                ElevatedButton(
                  onPressed: () {
                    getImage();
                  },
                  child: const Text('Capturar Foto'),
                ),
                if (_image != null)
                  Image.file(_image!)
                else
                  const Text('Nenhuma foto selecionada.'),
                TextField(
                  controller: nomeController,
                  decoration: const InputDecoration(labelText: 'Nome'),
                ),
                TextField(
                  controller: numeroTelefoneController,
                  decoration:
                      const InputDecoration(labelText: 'Número de Telefone'),
                ),
                const SizedBox(
                  height: 10,
                ),
                ElevatedButton(
                  onPressed: () {
                    if (_image != null) {
                      final nome = nomeController.text;
                      final numeroTelefone = numeroTelefoneController.text;
                      final caminhoFoto = _image!.path;
                      final newContact = Contato(
                        nome: nome,
                        numeroTelefone: numeroTelefone,
                        caminhoFoto: caminhoFoto,
                      );
                      Provider.of<ContactProvider>(context, listen: false)
                          .addContact(newContact);
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Salvar Contato'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
