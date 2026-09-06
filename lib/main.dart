import 'dart:convert';
import 'html_stub.dart' if (dart.library.html) 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MaterialApp(home: TelaInspecao()));
}

class TelaInspecao extends StatefulWidget {
  const TelaInspecao({super.key});

  @override
  State<TelaInspecao> createState() => _TelaInspecaoState();
}

class _TelaInspecaoState extends State<TelaInspecao> {
  String _formatarTexto(String texto) {
    if (texto.trim().isEmpty) return '';
    List<String> palavras = texto.trim().toLowerCase().split(' ');
    List<String> palavrasFormatadas = palavras.map((palavra) {
      if (palavra.isEmpty) return '';
      return palavra[0].toUpperCase() + palavra.substring(1);
    }).toList();
    return palavrasFormatadas.join(' ');
  }

  List<Map<String, dynamic>> _epis = [];

  String? _epiSelecionado;
  String _statusFisico = 'Aprovado';
  String _tempoValidade = '5 Anos';
  
  DateTime _dataInspecao = DateTime.now();
  DateTime _dataFabricacao = DateTime.now();
  DateTime _dataDieletrico = DateTime.now();

  List<Map<String, dynamic>> _historico = [];
  int? _editandoIndex;

  final _controladorNovoEpi = TextEditingController();
  String _novoTempoValidade = 'Indeterminado (Sem Validade)';
  bool _novoTemDieletrico = false;

  @override
  void initState() {
    super.initState();
    _carregarDadosSalvos();
  }

  Future<void> _carregarDadosSalvos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final String? historicoString = prefs.getString('historico_inspecoes') ?? html.window.localStorage['historico_inspecoes'];
      if (historicoString != null) {
        final List<dynamic> decodificado = jsonDecode(historicoString);
        setState(() {
          _historico = decodificado.map((e) => Map<String, dynamic>.from(e)).toList();
        });
      }

      final String? episString = prefs.getString('lista_epis') ?? html.window.localStorage['lista_epis'];
      if (episString != null) {
        final List<dynamic> decodificadoEpis = jsonDecode(episString);
        setState(() {
          _epis = decodificadoEpis.map((e) => Map<String, dynamic>.from(e)).toList();
        });
      }
    } catch (_) {}

    if (_epis.isNotEmpty) {
      setState(() {
        _epiSelecionado = _epis.first['nome'];
        _atualizarValidadePadrao(_epiSelecionado);
      });
    }
  }

  Future<void> _salvarDadosLocais() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historicoJson = jsonEncode(_historico);
      final episJson = jsonEncode(_epis);

      // Salva no celular e também no navegador para manter compatibilidade total
      await prefs.setString('historico_inspecoes', historicoJson);
      await prefs.setString('lista_epis', episJson);
      
      try {
        html.window.localStorage['historico_inspecoes'] = historicoJson;
        html.window.localStorage['lista_epis'] = episJson;
      } catch (_) {}
    } catch (_) {}
  }

  void _atualizarValidadePadrao(String? nomeEpi) {
    if (nomeEpi == null) return;
    final item = _epis.firstWhere((e) => e['nome'] == nomeEpi, orElse: () => {'valPadrao': '5 Anos'});
    setState(() {
      _tempoValidade = item['valPadrao'] ?? '5 Anos';
    });
  }

  Future<void> _escolherData(int tipo) async {
    DateTime atual = tipo == 0 ? _dataInspecao : (tipo == 1 ? _dataFabricacao : _dataDieletrico);
    DateTime? nova = await showDatePicker(
      context: context,
      initialDate: atual,
      firstDate: DateTime(2015),
      lastDate: DateTime(2040),
    );
    if (nova != null) {
      setState(() {
        if (tipo == 0) _dataInspecao = nova;
        if (tipo == 1) _dataFabricacao = nova;
        if (tipo == 2) _dataDieletrico = nova;
      });
    }
  }

  void _abrirModalNovoEpi() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return AlertDialog(
              title: const Text('Cadastrar Novo EPI / Ferramenta'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _controladorNovoEpi,
                      decoration: const InputDecoration(labelText: 'Nome do Equipamento'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _novoTempoValidade,
                      decoration: const InputDecoration(labelText: 'Validade Padrão do Fabricante'),
                      items: ['Indeterminado (Sem Validade)', '6 Meses', '1 Ano', '2 Anos', '5 Anos']
                          .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      onChanged: (v) => setStateModal(() => _novoTempoValidade = v!),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('Possui Ensaio Dielétrico?'),
                      value: _novoTemDieletrico,
                      onChanged: (v) => setStateModal(() => _novoTemDieletrico = v),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (_controladorNovoEpi.text.isNotEmpty) {
                      String nomeFormatado = _formatarTexto(_controladorNovoEpi.text);
                      setState(() {
                        if (!_epis.any((e) => e['nome'] == nomeFormatado)) {
                          _epis.add({
                            'nome': nomeFormatado,
                            'temDieletrico': _novoTemDieletrico,
                            'valPadrao': _novoTempoValidade,
                          });
                        }
                        _epiSelecionado = nomeFormatado;
                        _atualizarValidadePadrao(nomeFormatado);
                        _controladorNovoEpi.clear();
                      });
                      _salvarDadosLocais();
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _salvar() {
    if (_epiSelecionado == null) return;

    final epiInfo = _epis.firstWhere((e) => e['nome'] == _epiSelecionado, orElse: () => {'temDieletrico': false});
    bool exigeDieletrico = epiInfo['temDieletrico'] ?? false;

    DateTime? valFab;
    bool vencidoFab = false;
    bool alertaFab = false;
    String textoValFabricante = 'Indeterminado';

    if (_tempoValidade != 'Indeterminado (Sem Validade)') {
      if (_tempoValidade == '6 Meses') {
        valFab = DateTime(_dataFabricacao.year, _dataFabricacao.month + 6, _dataFabricacao.day);
      } else if (_tempoValidade == '1 Ano') {
        valFab = DateTime(_dataFabricacao.year + 1, _dataFabricacao.month, _dataFabricacao.day);
      } else if (_tempoValidade == '2 Anos') {
        valFab = DateTime(_dataFabricacao.year + 2, _dataFabricacao.month, _dataFabricacao.day);
      } else {
        valFab = DateTime(_dataFabricacao.year + 5, _dataFabricacao.month, _dataFabricacao.day);
      }

      vencidoFab = valFab.isBefore(DateTime.now());
      alertaFab = !vencidoFab && valFab.difference(DateTime.now()).inDays <= 45;
      textoValFabricante = "${valFab.day}/${valFab.month}/${valFab.year}";
    }

    bool vencidoDiel = exigeDieletrico && _dataDieletrico.isBefore(DateTime.now());
    bool vencido = vencidoFab || vencidoDiel;

    bool alertaDiel = exigeDieletrico && !vencidoDiel && _dataDieletrico.difference(DateTime.now()).inDays <= 45;
    bool alerta = alertaFab || alertaDiel;

    String statusFinal = _statusFisico;
    if (_statusFisico == 'Reprovado' || vencido) {
      statusFinal = 'Reprovado';
    }

    setState(() {
      final dados = {
        'epi': _epiSelecionado,
        'status': statusFinal,
        'vencido': vencido,
        'alerta': alerta,
        'valFab': textoValFabricante,
        'valDiel': exigeDieletrico ? "${_dataDieletrico.day}/${_dataDieletrico.month}/${_dataDieletrico.year}" : 'N/A',
      };

      if (_editandoIndex != null) {
        _historico[_editandoIndex!] = dados;
        _editandoIndex = null;
      } else {
        _historico.add(dados);
      }
    });

    _salvarDadosLocais();
  }

  void _excluir(int index) {
    setState(() {
      _historico.removeAt(index);
      if (_editandoIndex == index) _editandoIndex = null;
    });
    _salvarDadosLocais();
  }

  void _gerarResumo() {
    if (_historico.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhum registro no histórico para gerar resumo!')),
      );
      return;
    }

    int total = _historico.length;
    int conformes = _historico.where((h) => h['status'] == 'Aprovado' && !h['alerta']).length;

    var listaAlertas = _historico.where((h) => h['alerta'] && h['status'] == 'Aprovado').toList();
    var listaReprovados = _historico.where((h) => h['status'] == 'Reprovado').toList();

    String mensagemFormatada = "RELATÓRIO DE INSPEÇÃO DE EPIS E LINHA VIVA\n\n"
        "• Total de itens inspecionados: $total\n"
        "• Conformes / OK: $conformes\n"
        "• Em Alerta (< 45 dias): ${listaAlertas.length}\n";

    if (listaAlertas.isNotEmpty) {
      mensagemFormatada += "  - Itens em Alerta:\n";
      for (var item in listaAlertas) {
        mensagemFormatada += "    * ${item['epi']}\n";
      }
    }

    mensagemFormatada += "• Reprovados / Vencidos: ${listaReprovados.length}\n";

    if (listaReprovados.isNotEmpty) {
      mensagemFormatada += "  - Itens Reprovados:\n";
      for (var item in listaReprovados) {
        mensagemFormatada += "    * ${item['epi']}\n";
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resumo da Inspeção'),
        content: SingleChildScrollView(child: SelectableText(mensagemFormatada)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
            onPressed: () {
              final url = "https://wa.me/?text=${Uri.encodeComponent(mensagemFormatada)}";
              try {
                html.window.open(url, '_blank');
              } catch (_) {}
            },
            icon: const Icon(Icons.share, size: 18),
            label: const Text('Enviar WhatsApp'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final epiAtual = _epis.firstWhere((e) => e['nome'] == _epiSelecionado, orElse: () => {'temDieletrico': false});
    bool mostraDieletrico = epiAtual['temDieletrico'] ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Controle de EPIs e Linha Viva'), backgroundColor: Colors.blue.shade900, foregroundColor: Colors.white),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _epis.isEmpty
                      ? OutlinedButton.icon(
                          onPressed: _abrirModalNovoEpi,
                          icon: const Icon(Icons.add),
                          label: const Text('Cadastrar Primeiro EPI / Ferramenta'),
                        )
                      : DropdownButtonFormField<String>(
                          value: _epiSelecionado,
                          decoration: const InputDecoration(labelText: 'EPI / Ferramenta', border: OutlineInputBorder()),
                          items: _epis.map((e) => DropdownMenuItem(value: e['nome'].toString(), child: Text(e['nome']))).toList(),
                          onChanged: (v) {
                            setState(() {
                              _epiSelecionado = v;
                              _atualizarValidadePadrao(v);
                            });
                          },
                        ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  onPressed: _abrirModalNovoEpi,
                  icon: const Icon(Icons.add_box, color: Colors.blue),
                  tooltip: 'Adicionar novo EPI',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _statusFisico,
                    decoration: const InputDecoration(labelText: 'Inspeção Física', border: OutlineInputBorder()),
                    items: ['Aprovado', 'Reprovado'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) => setState(() => _statusFisico = v!),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _tempoValidade,
                    decoration: const InputDecoration(labelText: 'Val. Fabricante', border: OutlineInputBorder()),
                    items: ['Indeterminado (Sem Validade)', '6 Meses', '1 Ano', '2 Anos', '5 Anos']
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) => setState(() => _tempoValidade = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: () => _escolherData(0), child: Text('Insp: ${_dataInspecao.day}/${_dataInspecao.month}/${_dataInspecao.year}'))),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton(onPressed: () => _escolherData(1), child: Text('Fab: ${_dataFabricacao.day}/${_dataFabricacao.month}/${_dataFabricacao.year}'))),
                if (mostraDieletrico) ...[
                  const SizedBox(width: 8),
                  Expanded(child: OutlinedButton(onPressed: () => _escolherData(2), child: Text('Diel: ${_dataDieletrico.day}/${_dataDieletrico.month}/${_dataDieletrico.year}'))),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _salvar,
                    icon: Icon(_editandoIndex != null ? Icons.edit : Icons.save),
                    label: Text(_editandoIndex != null ? 'Atualizar Registro' : 'Registrar Inspeção'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade900, foregroundColor: Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _gerarResumo,
                  icon: const Icon(Icons.assessment),
                  label: const Text('Gerar Resumo'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Histórico:', style: TextStyle(fontWeight: FontWeight.bold)),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: _historico.length,
                itemBuilder: (context, index) {
                  final item = _historico[index];
                  bool isReprovadoOuVencido = item['status'] == 'Reprovado' || item['vencido'];
                  Color cor = isReprovadoOuVencido ? Colors.red : (item['alerta'] ? Colors.orange : Colors.green);
                  
                  String textoExtra = '';
                  if (item['vencido']) textoExtra = ' (VENCIDO - REPROVADO)';
                  else if (item['status'] == 'Reprovado') textoExtra = ' (AVARIADO - REPROVADO)';
                  else if (item['alerta']) textoExtra = ' (ALERTA: Vence em < 45 dias)';

                  return Card(
                    shape: RoundedRectangleBorder(side: BorderSide(color: cor, width: 2)),
                    child: ListTile(
                      onTap: () => setState(() {
                        _epiSelecionado = item['epi'];
                        _statusFisico = item['status'] == 'Reprovado' ? 'Reprovado' : 'Aprovado';
                        _editandoIndex = index;
                      }),
                      title: Text('${item['epi']}$textoExtra', style: TextStyle(fontWeight: FontWeight.bold, color: isReprovadoOuVencido ? Colors.red.shade900 : Colors.black87)),
                      subtitle: Text('Status Final: ${item['status']} | Val. Fab: ${item['valFab']} | Val. Diel: ${item['valDiel']}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.edit, size: 18, color: Colors.grey),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                            onPressed: () => _excluir(index),
                            tooltip: 'Excluir registro',
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}