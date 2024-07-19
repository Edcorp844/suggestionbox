import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:suggestion_box/login_screen.dart';

import 'suggestion.dart';

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: Text('User data not found'));
          }

          bool isAdmin = snapshot.data!['role'] == 'admin';

          return isAdmin
              ? AdminView(
                  user: user,
                )
              : UserView(
                  user: user,
                );
        },
      ),
    );
  }
}

class AdminView extends StatefulWidget {
  final User? user;

  const AdminView({super.key, this.user});
  @override
  State<AdminView> createState() => _AdminViewState();
}

class _AdminViewState extends State<AdminView> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _reactionController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        drawer: Drawer(
          child: Column(
            children: [
              UserAccountsDrawerHeader(
                currentAccountPicture: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(50),
                    image: const DecorationImage(
                      image: AssetImage('assets/1024.png'),
                    ),
                  ),
                ),
                accountName: Text(widget.user!.displayName ?? 'Anonymous'),
                accountEmail: Text(widget.user!.email!),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () async {
                  await FirebaseAuth.instance.signOut();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => LoginScreen()),
                  );
                },
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.logout),
                      onPressed: () {},
                    ),
                    const SizedBox(width: 10),
                    const Text('SignOut'),
                    const SizedBox(height: 100),
                  ],
                ),
              )
            ],
          ),
        ),
        appBar: AppBar(
          title: const Text(
            'Suggestion Box',
          ),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          centerTitle: true,
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.deepPurple[100],
            indicatorColor: Colors.white,
            tabs: const [
              Tab(text: 'All'),
              Tab(text: 'Reacted To'),
              Tab(text: 'Unreacted To'),
            ],
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: TabBarView(
                children: [
                  _buildSuggestionsStream(context, null),
                  _buildSuggestionsStream(context, true),
                  _buildSuggestionsStream(context, false),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionsStream(BuildContext context, bool? reacted) {
    Query query = _firestore.collection('suggestions');
    if (reacted != null) {
      query = query.where(
        'reaction',
        isNotEqualTo: reacted ? true : false,
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No suggestions found'));
        }

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var suggestion = snapshot.data!.docs[index];
              return Column(
                children: [
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: Colors.deepPurple[200],
                        borderRadius: BorderRadius.circular(20)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          suggestion['content'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(suggestion['timestamp'].toDate().toString()),
                            IconButton(
                              onPressed: () async {
                                bool? confirm = await showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text('Confirm Delete'),
                                    content: Text(
                                        'Are you sure you want to delete this suggestion?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(false),
                                        child: Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(true),
                                        child: Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  _deleteSuggestion(suggestion.id);
                                }
                              },
                              icon: const Icon(
                                CupertinoIcons.delete,
                              ),
                            ),
                            IconButton(
                              onPressed: () async {
                                bool? confirm = await showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text('React'),
                                    content: inPutBox(_reactionController,
                                        false, 'Enter reaction'),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(false),
                                        child: Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(true),
                                        child: Text('React'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true &&
                                    _reactionController.text.isNotEmpty) {
                                  react(context, suggestion.id,
                                      _reactionController.text.trim());
                                }
                              },
                              icon: const Icon(
                                CupertinoIcons.chat_bubble,
                              ),
                            )
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(
                    height: 2,
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void _deleteSuggestion(String suggestionId) async {
    try {
      await _firestore.collection('suggestions').doc(suggestionId).delete();
      print("Suggestion deleted successfully");
    } catch (e) {
      print("Failed to delete suggestion: $e");
    }
  }

  void react(context, String suggestionId, String reaction) async {
    try {
      await _firestore.collection('suggestions').doc(suggestionId).update({
        'reaction': reaction,
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to react: ${e.toString()}')),
      );
    }
  }

  Widget inPutBox(controller, obsecureText, hint) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        color: Colors.deepPurple[50],
      ),
      child: CupertinoTextField(
        placeholder: hint,
        controller: controller,
        obscureText: obsecureText,
        decoration: const BoxDecoration(),
        expands: true,
        maxLines: null,
        minLines: null,
      ),
    );
  }
}

class UserView extends StatelessWidget {
  final User? user;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _controller = TextEditingController();

  UserView({super.key, this.user});
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        drawer: Drawer(
          child: Column(
            children: [
              UserAccountsDrawerHeader(
                currentAccountPicture: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(50),
                    image: const DecorationImage(
                      image: AssetImage('assets/1024.png'),
                    ),
                  ),
                ),
                accountName: Text(user!.displayName ?? 'Anonymous'),
                accountEmail: Text(user!.email!),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () async {
                  await FirebaseAuth.instance.signOut();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => LoginScreen()),
                  );
                },
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.logout),
                      onPressed: () {},
                    ),
                    const SizedBox(width: 10),
                    const Text('SignOut'),
                    const SizedBox(height: 100),
                  ],
                ),
              )
            ],
          ),
        ),
        appBar: AppBar(
          title: const Text(
            'Suggestion Box',
          ),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          centerTitle: true,
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.deepPurple[100],
            indicatorColor: Colors.white,
            tabs: const [
              Tab(text: 'All'),
              Tab(text: 'Reacted To'),
              Tab(text: 'Unreacted To'),
            ],
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: TabBarView(
                children: [
                  _buildSuggestionsStream(context, null),
                  _buildSuggestionsStream(context, true),
                  _buildSuggestionsStream(context, false),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                      child: inPutBox(_controller, false, 'Enter suggestion')),
                  IconButton(
                    icon: Icon(
                      Icons.send,
                      color: Colors.deepPurple[600],
                    ),
                    onPressed: () {
                      if (_controller.text.isNotEmpty) {
                        final suggestion = Suggestion(
                          content: _controller.text,
                          timestamp: DateTime.now(),
                        );
                        FirebaseFirestore.instance
                            .collection('suggestions')
                            .add(suggestion.toJson());
                        _controller.clear();
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionsStream(BuildContext context, bool? reacted) {
    Query query = _firestore.collection('suggestions');
    if (reacted != null) {
      query = query.where(
        'reaction',
        isNotEqualTo: reacted ? true : false,
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No suggestions found'));
        }

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var suggestion = snapshot.data!.docs[index];
              return Column(
                children: [
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: Colors.deepPurple[200],
                        borderRadius: BorderRadius.circular(20)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          suggestion['content'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [],
                        )
                      ],
                    ),
                  ),
                  const SizedBox(
                    height: 2,
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget inPutBox(controller, obsecureText, hint) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        color: Colors.deepPurple[50],
      ),
      child: CupertinoTextField(
        placeholder: hint,
        controller: controller,
        obscureText: obsecureText,
        decoration: const BoxDecoration(),
        expands: true,
        maxLines: null,
        minLines: null,
      ),
    );
  }
}
