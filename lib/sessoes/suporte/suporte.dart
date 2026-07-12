import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SuportePage extends StatefulWidget {
  const SuportePage({super.key});

  @override
  State<SuportePage> createState() => _SuportePageState();
}

class _SuportePageState extends State<SuportePage> {
  final TextEditingController _mensagemController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _enviando = false;
  String? _nomeUsuario;

  final List<FAQItem> _faqs = [
    FAQItem(
      pergunta: 'Como redefinir minha senha?',
      resposta: 'Vá em Meu Perfil > Segurança > Alterar Senha.',
      isExpanded: false,
    ),
    FAQItem(
      pergunta: 'Onde vejo meu histórico?',
      resposta: 'Menu > Relatórios > Histórico de Atividades.',
      isExpanded: false,
    ),
    FAQItem(
      pergunta: 'Como exportar dados?',
      resposta: 'Configurações > Privacidade > Exportar dados.',
      isExpanded: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _carregarNomeUsuario();
  }

  @override
  void dispose() {
    _mensagemController.dispose();
    super.dispose();
  }

  Future<void> _carregarNomeUsuario() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final response = await Supabase.instance.client
            .from('usuarios')
            .select('nome')
            .eq('id', user.id)
            .single();

        if (mounted) {
          setState(() {
            _nomeUsuario = response['nome'] as String?;
          });
        }
      }
    } catch (e) {
      // Se não conseguir carregar, usa o ID do usuário
      final user = Supabase.instance.client.auth.currentUser;
      if (mounted) {
        setState(() {
          _nomeUsuario = user?.email ?? 'Usuário';
        });
      }
    }
  }

  Future<void> _launchWhatsApp() async {
    final url = Uri.parse('https://wa.me/5511998584376?text=Olá! Preciso de ajuda.');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchEmail() async {
    final url = Uri.parse('mailto:suporte@powertankapp.com.br?subject=Suporte PowerTank');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _enviarMensagem() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _enviando = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      
      // Inserir na tabela de ajuda
      await Supabase.instance.client
          .from('ajuda')
          .insert({
            'usuario_id': user?.id,
            'texto': _mensagemController.text.trim(),
            'status': 'pendente',
          });

      // Limpar campo
      _mensagemController.clear();

      // Mostrar confirmação
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mensagem enviada com sucesso!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao enviar: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _enviando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderSlim(),
                const SizedBox(height: 16),

                _buildContatoSlim(),
                const SizedBox(height: 16),

                _buildFormularioSlim(),
                const SizedBox(height: 16),

                _buildFAQsSlim(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSlim() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _box(),
      child: Row(
        children: [
          const Icon(Icons.support_agent, size: 28, color: Color(0xFF0D47A1)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Central de Suporte',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0D47A1)),
                ),
                if (_nomeUsuario != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Olá, $_nomeUsuario!',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContatoSlim() {
    return Row(
      children: [
        Expanded(
          child: _buildContatoCardSlim(
            icon: FontAwesomeIcons.whatsapp,
            title: 'WhatsApp',
            subtitle: 'Atendimento 24 horas',
            color: const Color(0xFF25D366),
            onTap: _launchWhatsApp,
            isFa: true,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildContatoCardSlim(
            icon: Icons.email,
            title: 'E-mail',
            subtitle: 'suporte@powertankapp.com.br',
            color: const Color(0xFFEA4335),
            onTap: _launchEmail,
          ),
        ),
      ],
    );
  }

  Widget _buildContatoCardSlim({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    bool isFa = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: _box(),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
              child: Center(
                child: isFa ? FaIcon(icon, size: 16, color: color) : Icon(icon, size: 18, color: color),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0D47A1))),
                Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormularioSlim() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _box(),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Envie sua dúvida',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0D47A1)),
            ),
            const SizedBox(height: 10),
            if (_nomeUsuario != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person, size: 18, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'De: $_nomeUsuario',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
            TextFormField(
              controller: _mensagemController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Descreva sua dúvida ou problema',
                alignLabelWithHint: true,
                prefixIcon: Align(
                  widthFactor: 1.0,
                  heightFactor: 1.0,
                  child: Icon(Icons.message, size: 18),
                ),
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().length < 10) 
                  ? 'Por favor, descreva com mais detalhes (mínimo 10 caracteres)' 
                  : null,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: ElevatedButton.icon(
                onPressed: _enviando ? null : _enviarMensagem,
                icon: _enviando
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send, size: 16),
                label: _enviando ? const Text('Enviando...') : const Text('Enviar mensagem'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D47A1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQsSlim() {
    return Container(
      decoration: _box(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Perguntas Frequentes',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0D47A1),
              ),
            ),
          ),
          ..._faqs.map((faq) {
            return ExpansionTile(
              dense: true,
              tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              title: Text(
                faq.pergunta,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF0D47A1)),
              ),
              childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    faq.resposta,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                ),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }

  BoxDecoration _box() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade100),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
      ],
    );
  }
}

class FAQItem {
  final String pergunta;
  final String resposta;
  bool isExpanded;

  FAQItem({
    required this.pergunta,
    required this.resposta,
    required this.isExpanded,
  });
}