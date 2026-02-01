import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/config_provider.dart';
import '../../providers/transactions_provider.dart';
import '../../models/config_models.dart';
import '../../utils/notifications.dart';
import '../../config/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _rateController;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<ConfigProvider>(context, listen: false);
    _rateController = TextEditingController(text: provider.exchangeRate.toString());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text("Configuración", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: AppColors.backgroundLight,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- SECCIÓN 1: COTIZACIÓN ---
                    Text("Ajustes Generales", style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: AppColors.textWhite)),
                    const Divider(color: Colors.white10),
                    const SizedBox(height: 20),
                    const Text("Cotización del Dólar (USD)", style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textGrey, fontSize: 16)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          constraints: const BoxConstraints(maxWidth: 250),
                          child: TextField(
                            controller: _rateController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.currency_exchange, color: AppColors.primaryPurple),
                              filled: true,
                              fillColor: AppColors.backgroundDark,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              hintText: "42.5",
                              hintStyle: TextStyle(color: Colors.grey.shade700),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              suffixIcon: Tooltip(
                                message: "Guardar",
                                child: InkWell(
                                  onTap: () {
                                    final val = double.tryParse(_rateController.text);
                                    if (val != null) {
                                      Provider.of<ConfigProvider>(context, listen: false).setExchangeRate(val);
                                      ModernFeedback.showSuccess(context, "Cotización guardada: \$U $val");
                                    } else {
                                      ModernFeedback.showError(context, "Error", "Ingresa un número válido.");
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    margin: const EdgeInsets.all(6),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.green.withOpacity(0.5)),
                                    ),
                                    child: const Icon(Icons.check, color: Colors.green, size: 20),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 50),

                    // --- SECCIÓN 2: DATOS MAESTROS ---
                    Text("Asignación de rubros", style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: AppColors.textWhite)),
                    const Divider(color: Colors.white10),
                    const SizedBox(height: 24),
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 800),
                        child: Row(
                          children: [
                            _buildBigCard(
                              context,
                              title: "Mis Rubros",
                              icon: Icons.pie_chart,
                              color: Colors.blueAccent,
                              onTap: () => showDialog(context: context, builder: (_) => const _ManageCategoriesDialog()),
                            ),
                            const SizedBox(width: 24),
                            _buildBigCard(
                              context,
                              title: "Reglas de Asignación",
                              icon: Icons.rule,
                              color: Colors.orangeAccent,
                              onTap: () => showDialog(context: context, builder: (_) => const _ManageRulesDialog()),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 50),

                     // --- SECCIÓN 3: COPIAS DE SEGURIDAD ---
                     const Text("Copias de Seguridad", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textWhite)),
                     const Divider(color: Colors.white10),
                     const SizedBox(height: 24),
                     
                     Container(
                       padding: const EdgeInsets.all(24),
                       decoration: BoxDecoration(
                         color: AppColors.backgroundDark,
                         borderRadius: BorderRadius.circular(16),
                         border: Border.all(color: Colors.white10),
                       ),
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                            Row(
                              children: [
                                const Icon(Icons.security, size: 28, color: AppColors.textGrey),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("Respaldo Local", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                                    Consumer<ConfigProvider>(
                                      builder: (ctx, provider, _) => Text(
                                        provider.lastBackup != null 
                                          ? "Último respaldo: ${DateFormat('dd/MM/yyyy HH:mm').format(provider.lastBackup!)}"
                                          : "Último respaldo: Nunca",
                                        style: TextStyle(color: Colors.grey[500], fontSize: 13),
                                      ),
                                    ),
                                  ],
                                )
                              ],
                            ),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.save_alt),
                                    label: const Text("Crear Respaldo"),
                                    style: ElevatedButton.styleFrom(
                                       backgroundColor: AppColors.primaryPurple,
                                       foregroundColor: Colors.white,
                                       padding: const EdgeInsets.symmetric(vertical: 16),
                                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    onPressed: () async {
                                      await Provider.of<ConfigProvider>(context, listen: false).performBackup();
                                      if (context.mounted) ModernFeedback.showSuccess(context, "Respaldo creado con éxito.");
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    icon: const Icon(Icons.restore),
                                    label: const Text("Restaurar"),
                                    style: OutlinedButton.styleFrom(
                                       foregroundColor: Colors.orange,
                                       side: const BorderSide(color: Colors.orange),
                                       padding: const EdgeInsets.symmetric(vertical: 16),
                                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    onPressed: () => _showRestoreDialog(context),
                                  ),
                                ),
                              ],
                            ),
                         ],
                       ),
                     ),

                    const SizedBox(height: 50),

                     // --- SECCIÓN 4: ZONA DE PELIGRO ---
                     const Text("Zona de Peligro", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.accentPink)),
                     const Divider(color: AppColors.accentPink),
                     const SizedBox(height: 24),
                     
                     Container(
                       decoration: BoxDecoration(
                         color: AppColors.accentPink.withOpacity(0.05),
                         borderRadius: BorderRadius.circular(16),
                         border: Border.all(color: AppColors.accentPink.withOpacity(0.2)),
                       ),
                       child: ListTile(
                         contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                         leading: Container(
                           padding: const EdgeInsets.all(12),
                           decoration: BoxDecoration(color: AppColors.accentPink.withOpacity(0.1), shape: BoxShape.circle),
                           child: const Icon(Icons.delete_forever, color: AppColors.accentPink),
                         ),
                         title: const Text("Borrado Masivo de Datos", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.accentPink)),
                         subtitle: Text("Eliminar transacciones por rango de fecha y cuenta.", style: TextStyle(color: Colors.grey[500])),
                         trailing: ElevatedButton(
                           style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentPink, foregroundColor: Colors.white),
                           onPressed: () => _showDeleteDialog(context),
                           child: const Text("Abrir Herramienta"),
                         ),
                       ),
                     ),
                     const SizedBox(height: 50),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBigCard(BuildContext context, {required String title, required IconData icon, required Color color, required VoidCallback onTap}) {
    return Expanded(
      child: _HoverCard(
        title: title,
        icon: icon,
        color: color,
        onTap: onTap,
      ),
    );
  }
}

class _HoverCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _HoverCard({required this.title, required this.icon, required this.color, required this.onTap});

  @override
  State<_HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<_HoverCard> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          height: 180,
          transform: Matrix4.identity()..scale(_isHovering ? 1.02 : 1.0),
          decoration: BoxDecoration(
            color: AppColors.backgroundDark,
            borderRadius: BorderRadius.circular(12), // Más cuadraditos
            boxShadow: _isHovering 
                ? [BoxShadow(color: widget.color.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))]
                : [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))],
            border: Border.all(
              color: _isHovering ? widget.color.withOpacity(0.5) : Colors.white10,
              width: _isHovering ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: widget.color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(widget.icon, size: 40, color: widget.color),
              ),
              const SizedBox(height: 16),
              Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 8),
              const Text("Gestionar datos", style: TextStyle(color: Colors.grey, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}

// --- DIÁLOGOS (REUTILIZADOS) ---

class _ManageCategoriesDialog extends StatefulWidget {
  const _ManageCategoriesDialog();
  @override
  State<_ManageCategoriesDialog> createState() => _ManageCategoriesDialogState();
}

class _ManageCategoriesDialogState extends State<_ManageCategoriesDialog> {
  String _search = "";

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ConfigProvider>(context);
    final filtered = provider.categories.where((c) => c.name.toLowerCase().contains(_search.toLowerCase())).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 600,
        height: 700,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Gestionar Rubros", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: "Buscar rubro...",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
              ),
              onChanged: (val) => setState(() => _search = val),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (ctx, i) {
                  final cat = filtered[i];
                  return ListTile(
                    leading: CircleAvatar(backgroundColor: _getColor(cat.type).withOpacity(0.2), child: Icon(_getIcon(cat.type), color: _getColor(cat.type), size: 18)),
                    title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(cat.type.name.toUpperCase(), style: const TextStyle(fontSize: 10)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _showEditCategory(context, provider, cat),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _confirmDelete(context, "Rubro", () => provider.removeCategory(cat.id)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _showEditCategory(context, provider, null),
              icon: const Icon(Icons.add),
              label: const Text("Agregar Nuevo Rubro"),
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            )
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, String item, VoidCallback onDelete) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Eliminar $item"),
        content: const Text("¿Estás seguro? Esta acción no se puede deshacer."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          TextButton(onPressed: () { onDelete(); Navigator.pop(ctx); }, child: const Text("Eliminar", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  void _showEditCategory(BuildContext context, ConfigProvider provider, Category? existing) {
    String name = existing?.name ?? "";
    CategoryType type = existing?.type ?? CategoryType.expense;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(existing == null ? "Nuevo Rubro" : "Editar Rubro"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: TextEditingController(text: name),
                decoration: const InputDecoration(labelText: "Nombre"),
                onChanged: (val) => name = val,
              ),
              const SizedBox(height: 16),
              DropdownButton<CategoryType>(
                value: type,
                isExpanded: true,
                items: CategoryType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.name.toUpperCase()))).toList(),
                onChanged: (val) => setState(() => type = val!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
            ElevatedButton(
              onPressed: () {
                if (existing == null) {
                  provider.addCategory(name, type);
                } else {
                  provider.editCategory(existing.id, name, type);
                }
                Navigator.pop(ctx);
              },
              child: const Text("Guardar"),
            ),
          ],
        ),
      ),
    );
  }
  
  Color _getColor(CategoryType t) {
     switch (t) { case CategoryType.income: return Colors.green; case CategoryType.expense: return Colors.red; case CategoryType.transfer: return Colors.blue; case CategoryType.savings: return Colors.orange; }
  }
  IconData _getIcon(CategoryType t) {
     switch (t) { case CategoryType.income: return Icons.arrow_upward; case CategoryType.expense: return Icons.arrow_downward; case CategoryType.transfer: return Icons.compare_arrows; case CategoryType.savings: return Icons.savings; }
  }
}

class _ManageRulesDialog extends StatefulWidget {
  const _ManageRulesDialog();
  @override
  State<_ManageRulesDialog> createState() => _ManageRulesDialogState();
}

class _ManageRulesDialogState extends State<_ManageRulesDialog> {
  String _search = "";

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ConfigProvider>(context);
    final filtered = provider.rules.where((r) => r.keyword.toLowerCase().contains(_search.toLowerCase())).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 700,
        height: 700,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Gestionar Reglas", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: "Buscar palabra clave...",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
              ),
              onChanged: (val) => setState(() => _search = val),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (ctx, i) {
                  final rule = filtered[i];
                  final cat = provider.getCategoryById(rule.categoryId);
                  return ListTile(
                    title: Text(rule.keyword, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Row(
                      children: [
                        const Text("Asigna a: "),
                        Chip(label: Text(cat?.name ?? "N/A", style: const TextStyle(fontSize: 10)), backgroundColor: Colors.grey[200], visualDensity: VisualDensity.compact),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _showEditRule(context, provider, rule),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _confirmDelete(context, "Regla", () => provider.removeRule(rule.id)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _showEditRule(context, provider, null),
              icon: const Icon(Icons.add),
              label: const Text("Agregar Nueva Regla"),
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            )
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, String item, VoidCallback onDelete) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Eliminar $item"),
        content: const Text("¿Estás seguro?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          TextButton(onPressed: () { onDelete(); Navigator.pop(ctx); }, child: const Text("Eliminar", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  void _showEditRule(BuildContext context, ConfigProvider provider, AssignmentRule? existing) {
    String keyword = existing?.keyword ?? "";
    String? selectedCatId = existing?.categoryId ?? (provider.categories.isNotEmpty ? provider.categories.first.id : null);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(existing == null ? "Nueva Regla" : "Editar Regla"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: TextEditingController(text: keyword),
                decoration: const InputDecoration(labelText: "Si la descripción contiene..."),
                onChanged: (val) => keyword = val,
              ),
              const SizedBox(height: 16),
              DropdownButton<String>(
                value: selectedCatId,
                isExpanded: true,
                items: provider.categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                onChanged: (val) => setState(() => selectedCatId = val),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
            ElevatedButton(
              onPressed: () {
                if (keyword.isNotEmpty && selectedCatId != null) {
                  if (existing == null) {
                    provider.addRule(keyword, selectedCatId!);
                  } else {
                    provider.editRule(existing.id, keyword, selectedCatId!);
                  }
                  Navigator.pop(ctx);
                }
              },
              child: const Text("Guardar"),
            ),
          ],
        ),
      ),
    );
  }
}

// --- DIALOGO DE BORRADO ---
void _showDeleteDialog(BuildContext context) {
  DateTimeRange? selectedRange;
  String selectedType = 'CUENTA_UYU';
  final controller = TextEditingController();
  
  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text("Borrado Masivo", style: TextStyle(color: Colors.red)),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Selecciona qué datos quieres borrar permanentemente."),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: selectedType,
                decoration: const InputDecoration(labelText: "Tipo de Cuenta", border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'CUENTA_UYU', child: Text("Caja de Ahorro (\$U)")),
                  DropdownMenuItem(value: 'CUENTA_USD', child: Text("Caja de Ahorro (U\$S)")),
                  DropdownMenuItem(value: 'TARJETA', child: Text("Tarjeta Visa")),
                ],
                onChanged: (val) => setState(() => selectedType = val!),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final picked = await showDateRangePicker(
                    context: context, 
                    firstDate: DateTime(2020), 
                    lastDate: DateTime.now(),
                    saveText: "SELECCIONAR",
                  );
                  if (picked != null) setState(() => selectedRange = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                     labelText: "Rango de Fechas",
                     border: OutlineInputBorder(),
                     suffixIcon: Icon(Icons.calendar_month),
                  ),
                  child: Text(selectedRange == null 
                    ? "Seleccionar..." 
                    : "${DateFormat('dd/MM/yy').format(selectedRange!.start)} - ${DateFormat('dd/MM/yy').format(selectedRange!.end)}"
                  ),
                ),
              ),
              const Divider(height: 30, thickness: 1),
              const Text("Seguridad: Escribe 'eliminar' para confirmar.", style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                decoration: const InputDecoration(hintText: "eliminar", border: OutlineInputBorder(), isDense: true),
                onChanged: (val) => setState(() {}),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: controller.text.toLowerCase() == 'eliminar' && selectedRange != null
                ? () {
                    // Obtener Provider del contexto PADRE (SettingsScreen), no del dialogo
                    Provider.of<TransactionsProvider>(context, listen: false).deleteTransactionsByRange(
                      start: selectedRange!.start,
                      end: selectedRange!.end,
                      type: selectedType
                    );
                    Navigator.pop(ctx);
                    ModernFeedback.showSuccess(context, "Datos eliminados correctamente.");
                  }
                : null,
            child: const Text("ELIMINAR DEFINITIVAMENTE"),
          ),
        ],
      ),
    ),
  );
}

// --- DIALOGO DE RESTAURACION ---
void _showRestoreDialog(BuildContext context) {
  final controller = TextEditingController();
  
  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text("Restaurar Sistema", style: TextStyle(color: Colors.orange)),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Se reemplazarán todos los datos actuales con la última copia de seguridad guardada."),
              const SizedBox(height: 10),
              const Text("Esta acción no se puede deshacer.", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              const Text("Seguridad: Escribe 'restaurar' para confirmar.", style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                decoration: const InputDecoration(hintText: "restaurar", border: OutlineInputBorder(), isDense: true),
                onChanged: (val) => setState(() {}),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            onPressed: controller.text.toLowerCase() == 'restaurar'
                ? () async {
                    Navigator.pop(ctx);
                    await Provider.of<ConfigProvider>(context, listen: false).performRestore(context);
                    if (context.mounted) ModernFeedback.showSuccess(context, "Sistema restaurado al punto anterior.");
                  }
                : null,
            child: const Text("RESTAURAR AHORA"),
          ),
        ],
      ),
    ),
  );
}
