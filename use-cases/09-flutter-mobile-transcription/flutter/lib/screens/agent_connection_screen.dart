import 'package:flutter/material.dart';
import '../data/livekit_agent_config.dart';
import '../routes.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_top_bar.dart';

class AgentConnectionScreen extends StatefulWidget {
  const AgentConnectionScreen({super.key});
  @override
  State<AgentConnectionScreen> createState() => _AgentConnectionScreenState();
}

class _AgentConnectionScreenState extends State<AgentConnectionScreen> {
  final _store = LiveKitAgentConfigStore();
  final _endpoint = TextEditingController();
  final _token = TextEditingController();
  final _name = TextEditingController();
  final _serverId = TextEditingController();
  LiveKitAgentConnectionMode _mode = LiveKitAgentConnectionMode.customEndpoint;
  bool _loading = true;
  bool _saving = false;
  bool _showToken = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final config = await _store.load();
      if (!mounted) return;
      _endpoint.text = config.endpoint;
      _token.text = config.accessToken;
      _name.text = config.agentName;
      _serverId.text = config.developmentServerId;
      _mode = config.mode;
    } catch (_) {
      if (!mounted) return;
      _error = 'Unable to read secure connection settings. Try again.';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    final config = LiveKitAgentConfig(
        endpoint: _endpoint.text,
        accessToken: _token.text,
        agentName: _name.text,
        mode: _mode,
        developmentServerId: _serverId.text);
    final error = config.validationError;
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _store.save(config);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Unable to save connection settings. Try again.';
        });
      }
    }
  }

  @override
  void dispose() {
    _endpoint.dispose();
    _token.dispose();
    _name.dispose();
    _serverId.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        extendBodyBehindAppBar: true,
        appBar: const BrandTopBar(leading: TopBarLeading.back),
        body: SafeArea(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(padding: const EdgeInsets.all(20), children: [
                    Text('Agent connection', style: AppType.display(size: 28)),
                    const SizedBox(height: 10),
                    Text(
                        'Connect to your EveryVoice agent and choose how it responds.',
                        style: AppType.body(
                            size: 14,
                            color: AppColors.onSurfaceVariant,
                            height: 1.5)),
                    const SizedBox(height: 24),
                    DropdownButtonFormField<LiveKitAgentConnectionMode>(
                        initialValue: _mode,
                        isExpanded: true,
                        decoration: const InputDecoration(
                            labelText: 'Connection method',
                            border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(
                              value:
                                  LiveKitAgentConnectionMode.hostedDevelopment,
                              child: Text('LiveKit hosted (development)')),
                          DropdownMenuItem(
                              value: LiveKitAgentConnectionMode.customEndpoint,
                              child: Text('Custom token endpoint')),
                        ],
                        onChanged: _saving
                            ? null
                            : (mode) {
                                if (mode == null) return;
                                setState(() {
                                  _mode = mode;
                                  _showToken = false;
                                  _error = null;
                                });
                              }),
                    const SizedBox(height: 18),
                    if (_mode ==
                        LiveKitAgentConnectionMode.hostedDevelopment) ...[
                      TextField(
                          controller: _serverId,
                          enabled: !_saving,
                          autocorrect: false,
                          enableSuggestions: false,
                          decoration: const InputDecoration(
                              labelText: 'Server ID',
                              helperText:
                                  'From your LiveKit token server settings.',
                              border: OutlineInputBorder())),
                      const SizedBox(height: 10),
                      Text(
                          'For development only. Use a custom token endpoint for production.',
                          style: AppType.body(
                              size: 13,
                              color: AppColors.onSurfaceVariant,
                              height: 1.4)),
                    ] else ...[
                      TextField(
                          controller: _endpoint,
                          enabled: !_saving,
                          keyboardType: TextInputType.url,
                          autocorrect: false,
                          decoration: const InputDecoration(
                              labelText: 'Token endpoint URL',
                              hintText: 'https://your-server.example/token',
                              border: OutlineInputBorder())),
                      const SizedBox(height: 18),
                      TextField(
                          controller: _token,
                          enabled: !_saving,
                          obscureText: !_showToken,
                          autocorrect: false,
                          enableSuggestions: false,
                          decoration: InputDecoration(
                              labelText: 'Endpoint access token',
                              helperText: 'Stored securely on this device.',
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                  tooltip: _showToken
                                      ? 'Hide access token'
                                      : 'Show access token',
                                  onPressed: () =>
                                      setState(() => _showToken = !_showToken),
                                  icon: Icon(_showToken
                                      ? Icons.visibility_off
                                      : Icons.visibility)))),
                    ],
                    const SizedBox(height: 18),
                    TextField(
                        controller: _name,
                        enabled: !_saving,
                        autocorrect: false,
                        decoration: const InputDecoration(
                            labelText: 'Agent name',
                            border: OutlineInputBorder())),
                    const SizedBox(height: 18),
                    Card(
                        child: ListTile(
                            leading: const Icon(Icons.tune,
                                color: AppColors.primary),
                            title: const Text('Personality'),
                            subtitle: const Text(
                                'Instructions for your next conversation'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: _saving
                                ? null
                                : () => Navigator.of(context)
                                    .pushNamed(Routes.agentPersonality))),
                    if (_error != null)
                      Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(_error!,
                              style: AppType.body(
                                  size: 13, color: AppColors.error))),
                    const SizedBox(height: 24),
                    FilledButton(
                        onPressed: _saving ? null : _save,
                        style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16)),
                        child: Text(_saving ? 'Saving…' : 'Save connection')),
                  ])),
      );
}
