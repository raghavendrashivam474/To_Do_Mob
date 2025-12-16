import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart'; // <--- THIS ONE
import 'dart:convert';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // Initialize Firebase
  runApp(const BeautifulTodoApp());
}

class BeautifulTodoApp extends StatelessWidget {
  const BeautifulTodoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Task Master',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF673AB7),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F9FD),
      ),
      // Auth Gate: Checks if user is logged in
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return const TodoListScreen(); // User is logged in
          }
          return const AuthScreen(); // User is NOT logged in
        },
      ),
    );
  }
}

// --- NEW AUTH SCREEN ---
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLogin = true; // Toggle between Login and Sign Up

 Future<void> _signInWithGoogle() async {
  try {
    // 1. Start the sign-in flow
    final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) return; // User canceled

    // 2. Get the auth details
    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

    // 3. Create a credential (UPDATED FOR V7.0)
    final OAuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    // 4. Sign in to Firebase
    await FirebaseAuth.instance.signInWithCredential(credential);
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
  }
}

  Future<void> _authWithEmail() async {
    try {
      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(25.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_person, size: 80, color: Color(0xFF673AB7)),
              const SizedBox(height: 20),
              Text(
                _isLogin ? "Welcome Back" : "Create Account",
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: "Email",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Password",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: _authWithEmail,
                  child: Text(_isLogin ? "Login" : "Sign Up"),
                ),
              ),
              const SizedBox(height: 20),
              const Text("OR"),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: _signInWithGoogle,
                  icon: const Icon(Icons.g_mobiledata, size: 30),
                  label: const Text("Continue with Google"),
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => setState(() => _isLogin = !_isLogin),
                child: Text(_isLogin ? "Need an account? Sign Up" : "Have an account? Login"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- YOUR EXISTING TODO SCREEN (With Logout added) ---
class TodoListScreen extends StatefulWidget {
  const TodoListScreen({super.key});

  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
  List<TodoItem> _todos = [];
  final TextEditingController _textFieldController = TextEditingController();
  final user = FirebaseAuth.instance.currentUser; // Get current user info

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Important: Use user.uid to separate data per user!
      final String? dataString = prefs.getString('todo_list_${user?.uid}');
      
      if (dataString != null) {
        final List<dynamic> jsonList = jsonDecode(dataString);
        setState(() {
          _todos = jsonList.map((item) => TodoItem.fromMap(item)).toList();
        });
      }
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final String dataString = jsonEncode(_todos.map((e) => e.toMap()).toList());
    // Save with User ID so users don't see each other's tasks on the same phone
    await prefs.setString('todo_list_${user?.uid}', dataString);
  }

  int get _activeCount => _todos.where((item) => !item.isDone).length;

  String get _currentDate {
    final now = DateTime.now();
    final List<String> months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final List<String> days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return "${days[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}";
  }

  void _addOrEditTodo({TodoItem? existingItem}) {
    if (existingItem != null) {
      _textFieldController.text = existingItem.title;
    } else {
      _textFieldController.clear();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            top: 25, left: 25, right: 25,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                existingItem == null ? 'New Task' : 'Edit Task',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _textFieldController,
                style: const TextStyle(fontSize: 18),
                decoration: InputDecoration(
                  hintText: "What's on your mind?",
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                ),
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  onPressed: () {
                    if (_textFieldController.text.isNotEmpty) {
                      setState(() {
                        if (existingItem != null) {
                          existingItem.title = _textFieldController.text;
                        } else {
                          _todos.add(TodoItem(
                            id: DateTime.now().toString(),
                            title: _textFieldController.text,
                          ));
                        }
                      });
                      _saveData();
                      Navigator.pop(context);
                    }
                  },
                  child: Text(existingItem == null ? 'Add to List' : 'Save Changes'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _deleteTodo(TodoItem todo) {
    setState(() {
      _todos.removeWhere((item) => item.id == todo.id);
    });
    _saveData();
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Task deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            setState(() {
              _todos.add(todo);
            });
            _saveData();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.only(top: 70, left: 25, right: 25, bottom: 35),
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF7E57C2), Theme.of(context).colorScheme.primary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(35), bottomRight: Radius.circular(35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Display User Email
                        Text("Hello, ${user?.email?.split('@')[0] ?? 'User'}", style: const TextStyle(color: Colors.white, fontSize: 16)),
                        const Text("My Tasks", style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                        Text(_currentDate, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                      ],
                    ),
                    // LOGOUT BUTTON
                    IconButton(
                      icon: const Icon(Icons.logout, color: Colors.white),
                      onPressed: () async {
                        await GoogleSignIn().signOut();
                        await FirebaseAuth.instance.signOut();
                      },
                    )
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _todos.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.spa, size: 80, color: Colors.grey.shade300),
                        const SizedBox(height: 20),
                        Text("Relax, you're free!", style: TextStyle(color: Colors.grey.shade400, fontSize: 18)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                    physics: const BouncingScrollPhysics(),
                    itemCount: _todos.length,
                    itemBuilder: (context, index) {
                      final todo = _todos[index];
                      return TodoCard(
                        todo: todo,
                        onChanged: (value) {
                          setState(() {
                            todo.isDone = value!;
                          });
                          _saveData();
                        },
                        onDelete: () => _deleteTodo(todo),
                        onEdit: () => _addOrEditTodo(existingItem: todo),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addOrEditTodo(),
        elevation: 4,
        backgroundColor: const Color(0xFF673AB7),
        icon: const Icon(Icons.add_task, color: Colors.white),
        label: const Text("Add Task", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

// Reuse your TodoCard and TodoItem classes here (paste them from previous code)
class TodoCard extends StatelessWidget {
  final TodoItem todo;
  final Function(bool?) onChanged;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const TodoCard({super.key, required this.todo, required this.onChanged, required this.onDelete, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(todo.id),
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: const Color(0xFFFF5252), borderRadius: BorderRadius.circular(20)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 25),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) => onDelete(),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => onChanged(!todo.isDone),
                  child: Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: todo.isDone ? const Color(0xFF673AB7) : Colors.transparent,
                      border: Border.all(color: todo.isDone ? const Color(0xFF673AB7) : Colors.grey.shade400, width: 2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: todo.isDone ? const Icon(Icons.check, size: 18, color: Colors.white) : null,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: todo.isDone ? 0.4 : 1.0,
                    child: Text(
                      todo.title,
                      style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF2D3436),
                        decoration: todo.isDone ? TextDecoration.lineThrough : TextDecoration.none,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.grey),
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TodoItem {
  String id;
  String title;
  bool isDone;

  TodoItem({required this.id, required this.title, this.isDone = false});

  Map<String, dynamic> toMap() => {'id': id, 'title': title, 'isDone': isDone};
  factory TodoItem.fromMap(Map<String, dynamic> map) => TodoItem(id: map['id'], title: map['title'], isDone: map['isDone']);
}