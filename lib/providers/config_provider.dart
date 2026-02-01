import 'package:uuid/uuid.dart';
import '../models/config_models.dart';
import '../services/firestore_service.dart';
import 'package:provider/provider.dart';
import 'transactions_provider.dart';
import 'budget_provider.dart';

class ConfigProvider extends ChangeNotifier {
  ConfigProvider() {
    loadData();
    checkLastBackup();
  }

  double _exchangeRate = 42.5;

  // --- RUBROS PRECARGADOS ---
  List<Category> _categories = [
    Category(id: '1', name: 'Ingresos laborales', type: CategoryType.income),
    Category(id: '2', name: 'Devoluciones de impuestos', type: CategoryType.income),
    Category(id: '3', name: 'Ingresos extra', type: CategoryType.income),
    Category(id: '4', name: 'Alquiler', type: CategoryType.expense),
    Category(id: '5', name: 'Gastos comunes', type: CategoryType.expense),
    Category(id: '6', name: 'Alimentación e higiene', type: CategoryType.expense),
    Category(id: '7', name: 'Transporte', type: CategoryType.expense),
    Category(id: '8', name: 'UTE', type: CategoryType.expense),
    Category(id: '9', name: 'ANTEL', type: CategoryType.expense),
    Category(id: '10', name: 'León', type: CategoryType.expense),
    Category(id: '11', name: 'Vestimenta', type: CategoryType.expense),
    Category(id: '12', name: 'Suscripciones', type: CategoryType.expense),
    Category(id: '13', name: 'Salidas y ocio', type: CategoryType.expense),
    Category(id: '14', name: 'Impuestos y tributos', type: CategoryType.expense),
    Category(id: '15', name: 'Estética', type: CategoryType.expense),
    Category(id: '16', name: 'Retiro de efectivo', type: CategoryType.expense),
    Category(id: '17', name: 'Salud', type: CategoryType.expense),
    Category(id: '18', name: 'Educación', type: CategoryType.expense),
    Category(id: '19', name: 'Artículos tecnológicos', type: CategoryType.expense),
    Category(id: '20', name: 'Artículos del hogar', type: CategoryType.expense),
    Category(id: '21', name: 'Otros egresos', type: CategoryType.expense),
    Category(id: '22', name: 'Ahorro', type: CategoryType.savings),
    Category(id: '23', name: 'Movimiento puente', type: CategoryType.transfer),
    Category(id: '24', name: 'Categoría no asignada', type: CategoryType.transfer),
  ];

  // --- REGLAS PRECARGADAS ---
  List<AssignmentRule> _rules = [
    AssignmentRule(id: 'rule_0', keyword: 'REPUBLICA AFAP S.A.', categoryId: '1'),
    AssignmentRule(id: 'rule_1', keyword: 'ALFEO GUSTAVO BRUM', categoryId: '4'),
    AssignmentRule(id: 'rule_2', keyword: 'NOSTRUM TOWER', categoryId: '5'),
    AssignmentRule(id: 'rule_3', keyword: 'SABROSO', categoryId: '6'),
    AssignmentRule(id: 'rule_4', keyword: 'Copay', categoryId: '7'),
    AssignmentRule(id: 'rule_5', keyword: 'ALVAREZ LUBERTO DIEGO OSCAR', categoryId: '3'),
    AssignmentRule(id: 'rule_6', keyword: 'PAGO DE SERVICIO POR BANRED SERVICIO DE PAGOS BANRED , UTE', categoryId: '8'),
    AssignmentRule(id: 'rule_7', keyword: 'ANTEL', categoryId: '9'),
    AssignmentRule(id: 'rule_8', keyword: 'CINES LIFE', categoryId: '13'),
    AssignmentRule(id: 'rule_9', keyword: 'FSOLID', categoryId: '14'),
    AssignmentRule(id: 'rule_10', keyword: 'Lucky Experiencia', categoryId: '15'),
    AssignmentRule(id: 'rule_11', keyword: 'RETIRO EFECTIVO', categoryId: '16'),
    AssignmentRule(id: 'rule_12', keyword: 'NICOLAS SAMURIO', categoryId: '17'),
    AssignmentRule(id: 'rule_13', keyword: 'Amvstor', categoryId: '19'),
    AssignmentRule(id: 'rule_14', keyword: 'Tiendas Montevideo', categoryId: '20'),
    AssignmentRule(id: 'rule_15', keyword: 'Envio Estado De Cta.', categoryId: '21'),
    AssignmentRule(id: 'rule_16', keyword: 'PAGO ELECTRONICO TARJETA CREDITO', categoryId: '23'),
    AssignmentRule(id: 'rule_17', keyword: 'TIENDA INGLESA', categoryId: '6'),
    AssignmentRule(id: 'rule_18', keyword: 'RADIOTAXI141', categoryId: '7'),
    AssignmentRule(id: 'rule_19', keyword: 'ANCEL', categoryId: '9'),
    AssignmentRule(id: 'rule_20', keyword: 'Seguro Saldo Deudor', categoryId: '14'),
    AssignmentRule(id: 'rule_21', keyword: 'FARMASHOP', categoryId: '17'),
    AssignmentRule(id: 'rule_22', keyword: 'TOP TECNO UY', categoryId: '19'),
    AssignmentRule(id: 'rule_23', keyword: 'KIOSKO TERMINAL', categoryId: '6'),
    AssignmentRule(id: 'rule_24', keyword: 'STM       REC RECARGAS S', categoryId: '7'),
    AssignmentRule(id: 'rule_25', keyword: 'ZURICH SANTANDER', categoryId: '14'),
    AssignmentRule(id: 'rule_26', keyword: 'LA MOLIENDA ACJ', categoryId: '6'),
    AssignmentRule(id: 'rule_27', keyword: 'CPATU', categoryId: '7'),
    AssignmentRule(id: 'rule_28', keyword: 'DISCO N', categoryId: '6'),
    AssignmentRule(id: 'rule_29', keyword: 'CABIFY', categoryId: '7'),
    AssignmentRule(id: 'rule_30', keyword: 'SUPER DON PAULINO', categoryId: '6'),
    AssignmentRule(id: 'rule_31', keyword: 'TATA', categoryId: '6'),
    AssignmentRule(id: 'rule_32', keyword: 'zara', categoryId: '11'),
    AssignmentRule(id: 'rule_33', keyword: 'temu', categoryId: '11'),
    AssignmentRule(id: 'rule_34', keyword: 'Pago Supernet', categoryId: '23'),
    AssignmentRule(id: 'rule_35', keyword: 'Apple Com Bill', categoryId: '12'),
    AssignmentRule(id: 'rule_36', keyword: 'Eternity Cord', categoryId: '15'),
    AssignmentRule(id: 'rule_37', keyword: 'Renner', categoryId: '11'),
    AssignmentRule(id: 'rule_38', keyword: 'Toto', categoryId: '11'),
    AssignmentRule(id: 'rule_39', keyword: 'Tiendas Montevi', categoryId: '20'),
    AssignmentRule(id: 'rule_40', keyword: 'Emporio Del Hog', categoryId: '20'),
    AssignmentRule(id: 'rule_41', keyword: 'Sodimac', categoryId: '20'),
    AssignmentRule(id: 'rule_42', keyword: 'Loi   Vta Web', categoryId: '20'),
    AssignmentRule(id: 'rule_43', keyword: 'Openai  Chatgpt Subscr', categoryId: '12'),
    AssignmentRule(id: 'rule_44', keyword: 'Tiendamiauycred', categoryId: '19'),
    AssignmentRule(id: 'rule_45', keyword: 'Divino', categoryId: '20'),
    AssignmentRule(id: 'rule_46', keyword: 'Microsoft 365 P', categoryId: '12'),
    AssignmentRule(id: 'rule_47', keyword: 'Uruforu', categoryId: '11'),
    AssignmentRule(id: 'rule_48', keyword: 'Office 2000', categoryId: '19'),
    AssignmentRule(id: 'rule_49', keyword: 'Danafort', categoryId: '6'),
    AssignmentRule(id: 'rule_50', keyword: 'San Roque', categoryId: '15'),
    AssignmentRule(id: 'rule_51', keyword: 'Entraste', categoryId: '13'),
    AssignmentRule(id: 'rule_52', keyword: 'Ccee2026', categoryId: '21'),
    AssignmentRule(id: 'rule_53', keyword: 'S E M M', categoryId: '17'),
    AssignmentRule(id: 'rule_54', keyword: 'El Bar Paysandu', categoryId: '6'),
    AssignmentRule(id: 'rule_55', keyword: '25 Horas Kings', categoryId: '6'),
    AssignmentRule(id: 'rule_56', keyword: 'Pedidosya', categoryId: '6'),
    AssignmentRule(id: 'rule_57', keyword: 'CREDITO POR OPERACION EN SUPERNET P--/VACARO CASTRO ALEJANDRO', categoryId: '23'),
    AssignmentRule(id: 'rule_58', keyword: 'SANTIAGO RONDAN', categoryId: '15'),
    AssignmentRule(id: 'rule_59', keyword: 'MIQOZ AGUIRRE ELIZABETH RAQUEL', categoryId: '6'),
    AssignmentRule(id: 'rule_60', keyword: 'PEREZ ANGELOZZI, LEONELLA GER', categoryId: '6'),
    AssignmentRule(id: 'rule_61', keyword: 'LEO BURGUER', categoryId: '6'),
    AssignmentRule(id: 'rule_62', keyword: 'Matesur', categoryId: '20'),
    AssignmentRule(id: 'rule_63', keyword: 'Cot Web', categoryId: '7'),
    AssignmentRule(id: 'rule_64', keyword: '1Password', categoryId: '12'),
    AssignmentRule(id: 'rule_65', keyword: 'Grido', categoryId: '6'),
    AssignmentRule(id: 'rule_66', keyword: 'Cerlisol S A', categoryId: '17'),
    AssignmentRule(id: 'rule_67', keyword: 'Laika', categoryId: '10'),
    AssignmentRule(id: 'rule_68', keyword: 'Prolimpio', categoryId: '6'),
    AssignmentRule(id: 'rule_69', keyword: 'La Nueva Fabr', categoryId: '6'),
    AssignmentRule(id: 'rule_70', keyword: 'Uruforussa', categoryId: '11'),
    AssignmentRule(id: 'rule_71', keyword: 'Columbia', categoryId: '11'),
    AssignmentRule(id: 'rule_72', keyword: 'Lehmeyun', categoryId: '6'),
    AssignmentRule(id: 'rule_73', keyword: 'I.V.A.', categoryId: '14'),
    AssignmentRule(id: 'rule_74', keyword: 'Cuota Anual', categoryId: '14'),
    AssignmentRule(id: 'rule_75', keyword: 'IGNACIO PLAZ', categoryId: '6'),
    AssignmentRule(id: 'rule_76', keyword: 'EDINSON GOMEZ', categoryId: '6'),
    AssignmentRule(id: 'rule_77', keyword: 'COSEM', categoryId: '17'),
    AssignmentRule(id: 'rule_78', keyword: 'FALIU DANGELO SOPHIA ANTONELLA', categoryId: '3'),
    AssignmentRule(id: 'rule_79', keyword: 'CREW, PASO DE CARR', categoryId: '13'),
    AssignmentRule(id: 'rule_80', keyword: 'GRAN CANAL BAZAR', categoryId: '20'),
    AssignmentRule(id: 'rule_81', keyword: 'LCLUB MONTEVI', categoryId: '13'),
    AssignmentRule(id: 'rule_82', keyword: 'ALEJANDRA QUINTERO', categoryId: '6'),
    AssignmentRule(id: 'rule_83', keyword: 'DEVOLUCION IVA', categoryId: '2'),
    AssignmentRule(id: 'rule_84', keyword: 'PATRICIA FIORINA', categoryId: '21'),
    AssignmentRule(id: 'rule_85', keyword: 'CAROLINA PETRASLADOS', categoryId: '10'),
    AssignmentRule(id: 'rule_86', keyword: 'ORREGO REVELLO DANILO', categoryId: '10'),
    AssignmentRule(id: 'rule_87', keyword: 'DELICREAM, SORIANO', categoryId: '6'),
    AssignmentRule(id: 'rule_88', keyword: 'PRESTAMO SUPERNET', categoryId: '23'),
    AssignmentRule(id: 'rule_89', keyword: 'EL CLON REQUENA', categoryId: '20'),
    AssignmentRule(id: 'rule_90', keyword: 'UBER', categoryId: '7'),
    AssignmentRule(id: 'rule_91', keyword: 'BENI    BENI    AND    BEL', categoryId: '6'),
    AssignmentRule(id: 'rule_92', keyword: 'MAXIMI      PER', categoryId: '6'),
    AssignmentRule(id: 'rule_93', keyword: 'FERNANDO BARCELO', categoryId: '21'),
    AssignmentRule(id: 'rule_94', keyword: 'SOLE MARTINEZ', categoryId: '21'),
    AssignmentRule(id: 'rule_95', keyword: 'ROBUSTA CAFE', categoryId: '6'),
    AssignmentRule(id: 'rule_96', keyword: 'EMPORIO DE LOS SANDW', categoryId: '6'),
    AssignmentRule(id: 'rule_97', keyword: 'AXION BULEVAR', categoryId: '6'),
    AssignmentRule(id: 'rule_98', keyword: 'KINKO', categoryId: '6'),
    AssignmentRule(id: 'rule_99', keyword: 'DEVOLUCION IRPF', categoryId: '2'),
    AssignmentRule(id: 'rule_100', keyword: 'COMIDA LEÓN', categoryId: '10'),
    AssignmentRule(id: 'rule_101', keyword: 'FARMACIA ANTARTIDA', categoryId: '21'),
    AssignmentRule(id: 'rule_102', keyword: 'PIDEHOUSE', categoryId: '6'),
    AssignmentRule(id: 'rule_103', keyword: 'PANADERIA PERMEDES', categoryId: '6'),
    AssignmentRule(id: 'rule_104', keyword: 'America Cuota', categoryId: '11'),
    AssignmentRule(id: 'rule_105', keyword: 'Fil Cuota', categoryId: '20'),
    AssignmentRule(id: 'rule_106', keyword: '2Pr Cuota', categoryId: '20'),
    AssignmentRule(id: 'rule_107', keyword: 'Arr Cuota', categoryId: '20'),
    AssignmentRule(id: 'rule_108', keyword: 'Mul Cuota', categoryId: '20'),
    AssignmentRule(id: 'rule_109', keyword: 'Tienda Soy Sant', categoryId: '20'),
    AssignmentRule(id: 'rule_110', keyword: 'DE LA CRUZ CU A MARCELO AGUST(FORUS)', categoryId: '11'),
    AssignmentRule(id: 'rule_111', keyword: 'Microsoft Store', categoryId: '12'),
    AssignmentRule(id: 'rule_112', keyword: 'Mundopeludo', categoryId: '10'),
    AssignmentRule(id: 'rule_113', keyword: 'PIN UP POOL', categoryId: '13'),
    AssignmentRule(id: 'rule_114', keyword: 'Microsoft 1 Mes Para Pc', categoryId: '12'),
    AssignmentRule(id: 'rule_115', keyword: 'Redtickets Sas', categoryId: '13'),
    AssignmentRule(id: 'rule_116', keyword: 'COMISION POR RETIRO EN OTRAS REDES', categoryId: '14'),
    AssignmentRule(id: 'rule_117', keyword: 'BORCAM EQUIP.', categoryId: '20'),
    AssignmentRule(id: 'rule_118', keyword: '58Semanadelace', categoryId: '13'),
    AssignmentRule(id: 'rule_119', keyword: 'Gemarke Cuota', categoryId: '20'),
    AssignmentRule(id: 'rule_120', keyword: 'IMMONT', categoryId: '14'),
    AssignmentRule(id: 'rule_121', keyword: 'DISTRIMARKET', categoryId: '6'),
    AssignmentRule(id: 'rule_122', keyword: 'PAGO TOTAL CRÉDITO COMERCIAL', categoryId: '23'),
    AssignmentRule(id: 'rule_123', keyword: 'Merpago Jominar Cuota', categoryId: '20'),
    AssignmentRule(id: 'rule_124', keyword: '05/03/2025 - Merpago Distribui2', categoryId: '20'),
    AssignmentRule(id: 'rule_125', keyword: '05/03/2025 - Merpago Mercado Cuota', categoryId: '20'),
    AssignmentRule(id: 'rule_126', keyword: '06/03/2025 - Merpago Mercadolibre', categoryId: '20'),
    AssignmentRule(id: 'rule_127', keyword: 'COMPRA CON TARJETA DEBITO NATALIA QUINT.HANDY., PAYSANDU TARJ: ############9112', categoryId: '21'),
    AssignmentRule(id: 'rule_128', keyword: '17/05/2025 - Merpago Mercadolibre', categoryId: '19'),
    AssignmentRule(id: 'rule_129', keyword: '21/05/2025 - Merpago Randers', categoryId: '21'),
    AssignmentRule(id: 'rule_130', keyword: '02/06/2025 - Merpago Cat', categoryId: '11'),
    AssignmentRule(id: 'rule_131', keyword: 'Merpago Rodrigo', categoryId: '6'),
    AssignmentRule(id: 'rule_132', keyword: 'COMPRA CON TARJETA DEBITO MERCADO REGALO, MONTEVIDEO TARJ: ############9112', categoryId: '21'),
    AssignmentRule(id: 'rule_133', keyword: 'DEBITO OPERACION EN SUPERNET O SMS 791538TT55119098 TRF. PLAZA- JO MAR MEN', categoryId: '21'),
    AssignmentRule(id: 'rule_134', keyword: 'COMPRA CON TARJETA DEBITO MERPAGO.MERCADOLIBRE, MONTEVIDEO TARJ: ############9112', categoryId: '21'),
    AssignmentRule(id: 'rule_135', keyword: '30/06/2025 - Merpago Mercadolibre', categoryId: '10'),
    AssignmentRule(id: 'rule_136', keyword: '25/06/2025 - Merpago Everest', categoryId: '20'),
    AssignmentRule(id: 'rule_137', keyword: 'DEBITO OPERACION EN SUPERNET O SMS T NI IDEA', categoryId: '21'),
    AssignmentRule(id: 'rule_138', keyword: 'COMPRA CON TARJETA DEBITO EL DESPERTAR, MONTEVIDEO TARJ: ############9112', categoryId: '6'),
    AssignmentRule(id: 'rule_139', keyword: 'COMPRA CON TARJETA DEBITO 1785/1363/275/170 CP, MONTEVIDEO TARJ: ############9112', categoryId: '21'),
    AssignmentRule(id: 'rule_140', keyword: 'TCONSULTA LEÓN', categoryId: '10'),
    AssignmentRule(id: 'rule_141', keyword: 'ASOCIACION ESPANOLA', categoryId: '17'),
    AssignmentRule(id: 'rule_142', keyword: 'MAXIMILIANO PERERA', categoryId: '6'),
    AssignmentRule(id: 'rule_143', keyword: 'PASSLINE, PASO CARRASCO', categoryId: '13'),
    AssignmentRule(id: 'rule_144', keyword: 'TRANSF INSTANTANEA RECIBIDA 479115LR:250821020612072 VACARO CASTRO, ALEJANDRO ALFR', categoryId: '3'),
    AssignmentRule(id: 'rule_145', keyword: '24/07/2025 - Merpago Mostaza Cuota 02 02', categoryId: '10'),
    AssignmentRule(id: 'rule_146', keyword: '24/07/2025 - Merpago Mundope Cuota 02 02', categoryId: '10'),
    AssignmentRule(id: 'rule_147', keyword: 'COMPRA CON TARJETA DEBITO 2245/2243/2244/2242, MONTEVIDEO TARJ: ############9112', categoryId: '21'),
    AssignmentRule(id: 'rule_148', keyword: 'DE LA CRUZ CU A MARCELO AGUST(COMPRAS_POR_PERDIDA_TARJETA)', categoryId: '6'),
    AssignmentRule(id: 'rule_149', keyword: 'COMPRA CON TARJETA DEBITO MI ENTRADA', categoryId: '13'),
    AssignmentRule(id: 'rule_150', keyword: 'SUI YUAN', categoryId: '6'),
    AssignmentRule(id: 'rule_151', keyword: 'PREX16069506 ALEJANDRO VACARO', categoryId: '3'),
    AssignmentRule(id: 'rule_152', keyword: 'DEPOSITOS EN EFECTIVO CORRESPONSAL , MONTEVIDEO TARJ: ############9112', categoryId: '23'),
    AssignmentRule(id: 'rule_153', keyword: 'MOSCA HNOS', categoryId: '21'),
    AssignmentRule(id: 'rule_154', keyword: 'MERPAGO.COBRABITS', categoryId: '13'),
    AssignmentRule(id: 'rule_155', keyword: 'GUILLERMO VANELLI', categoryId: '21'),
    AssignmentRule(id: 'rule_156', keyword: 'JUANES STELAR', categoryId: '6'),
    AssignmentRule(id: 'rule_157', keyword: 'COMPRA CON TARJETA DEBITO MOV 1643/1644/1645/1', categoryId: '21'),
    AssignmentRule(id: 'rule_158', keyword: 'REST AVOCADO', categoryId: '6'),
    AssignmentRule(id: 'rule_159', keyword: 'Super Liro', categoryId: '6'),
    AssignmentRule(id: 'rule_160', keyword: 'Cacao Mvd', categoryId: '6'),
    AssignmentRule(id: 'rule_161', keyword: 'Asociacion Espa', categoryId: '17'),
    AssignmentRule(id: 'rule_162', keyword: 'Spotify', categoryId: '12'),
    AssignmentRule(id: 'rule_163', keyword: 'PRONPR', categoryId: '23'),
    AssignmentRule(id: 'rule_164', keyword: 'HELIUM', categoryId: '13'),
    AssignmentRule(id: 'rule_165', keyword: 'EL DURAZNO', categoryId: '6'),
    AssignmentRule(id: 'rule_166', keyword: 'CORDOBA BIARDO, YAEL /LORENZ', categoryId: '6'),
    AssignmentRule(id: 'rule_167', keyword: 'TRAVIESO BIDEGAIN DIEGO DESPEDIDA', categoryId: '5'),
    AssignmentRule(id: 'rule_168', keyword: 'PERERA HERNANDEZ MAXIMILIANO DESPEDIDA', categoryId: '5'),
    AssignmentRule(id: 'rule_169', keyword: 'PLAZ ARENA, IGNACIO GABRIEL DESPEDIDA', categoryId: '5'),
    AssignmentRule(id: 'rule_170', keyword: 'GONZALO RODRIGUEZ', categoryId: '6'),
    AssignmentRule(id: 'rule_171', keyword: 'PARENTINI DIAZ, ADRIANA CECIL DESPEDIDA', categoryId: '5'),
    AssignmentRule(id: 'rule_172', keyword: 'Super Con Amor', categoryId: '6'),
    AssignmentRule(id: 'rule_173', keyword: 'Merpago Seguros Cuota', categoryId: '4'),
    AssignmentRule(id: 'rule_174', keyword: 'PUNTO DULCE', categoryId: '6'),
    AssignmentRule(id: 'rule_175', keyword: 'COMISION POR DEPOSITOS ABITAB MOVIMIENTOS CORRESPONSALES', categoryId: '14'),
    AssignmentRule(id: 'rule_176', keyword: 'BELEN BENITEZ DESPEDIDA', categoryId: '13'),
    AssignmentRule(id: 'rule_177', keyword: 'YERLI OZAN NO SE QUE ES', categoryId: '6'),
    AssignmentRule(id: 'rule_178', keyword: 'ALEJANDRO VACARO JIME PERALTA', categoryId: '21'),
    AssignmentRule(id: 'rule_179', keyword: 'LAURA CARLE BAR RODO', categoryId: '13'),
    AssignmentRule(id: 'rule_180', keyword: 'Qpasopana', categoryId: '6'),
    AssignmentRule(id: 'rule_181', keyword: 'Quesur', categoryId: '6'),
    AssignmentRule(id: 'rule_182', keyword: 'Capcut', categoryId: '12'),
    AssignmentRule(id: 'rule_183', keyword: 'Underar Cuota', categoryId: '11'),
    AssignmentRule(id: 'rule_184', keyword: 'Cat     Cuota', categoryId: '11'),
    AssignmentRule(id: 'rule_185', keyword: 'Mariobarakus', categoryId: '6'),
    AssignmentRule(id: 'rule_186', keyword: 'LAPETINA  GC', categoryId: '5'),
    AssignmentRule(id: 'rule_187', keyword: '24117852 DE LA CRUZ CU A MARCELO AGUST', categoryId: '6'),
    AssignmentRule(id: 'rule_188', keyword: 'Autoservice Vanix', categoryId: '6'),
    AssignmentRule(id: 'rule_189', keyword: 'Merpago Sep     Cuota', categoryId: '19'),
    AssignmentRule(id: 'rule_190', keyword: 'Agencia Central Sa', categoryId: '7'),
    AssignmentRule(id: 'rule_191', keyword: 'Crew', categoryId: '13'),
    AssignmentRule(id: 'rule_192', keyword: '24 Horas Santy', categoryId: '6'),
    AssignmentRule(id: 'rule_193', keyword: 'Cellular Center Cuota 01 02', categoryId: '21'),
    AssignmentRule(id: 'rule_194', keyword: 'Angela Moreira', categoryId: '6'),
    AssignmentRule(id: 'rule_195', keyword: 'Merpago Newyearbynosle', categoryId: '13'),
    AssignmentRule(id: 'rule_196', keyword: 'Taxi Paysandu', categoryId: '7'),
    AssignmentRule(id: 'rule_197', keyword: 'Merpago Nutrifi Cuota', categoryId: '15'),
    AssignmentRule(id: 'rule_198', keyword: 'Merpago Mcdonalds', categoryId: '6'),
    AssignmentRule(id: 'rule_199', keyword: 'Kiosco Nueva Paula', categoryId: '6'),
    AssignmentRule(id: 'rule_200', keyword: 'Raciones Del Litoral', categoryId: '21'),
    AssignmentRule(id: 'rule_201', keyword: 'Bimba Bruder Juncal', categoryId: '13'),
    AssignmentRule(id: 'rule_202', keyword: 'Bimba Bruder Av Salto', categoryId: '13'),
    AssignmentRule(id: 'rule_203', keyword: 'Altosur 6', categoryId: '6'),
    AssignmentRule(id: 'rule_204', keyword: 'Rodrigo Muebles', categoryId: '19'),
    AssignmentRule(id: 'rule_205', keyword: 'MERPAGO.ROCKFORD', categoryId: '11'),
    AssignmentRule(id: 'rule_206', keyword: 'MERPAGO.FORUSUY', categoryId: '11'),
    AssignmentRule(id: 'rule_207', keyword: 'Merpago Merrell Cuota', categoryId: '11'),
    AssignmentRule(id: 'rule_208', keyword: 'DE LA CRUZ CU A MARCELO AGUST (ROPA)', categoryId: '11'),
    AssignmentRule(id: 'rule_209', keyword: 'Merpago Atrix', categoryId: '10'),
    AssignmentRule(id: 'rule_210', keyword: 'H M', categoryId: '11'),
    AssignmentRule(id: 'rule_211', keyword: 'Goddard   Dgi', categoryId: '6'),
    AssignmentRule(id: 'rule_212', keyword: 'Babilonia', categoryId: '6'),
    AssignmentRule(id: 'rule_213', keyword: 'DEBITO OPERACION EN SUPERNET O SMS T (Operación León)', categoryId: '10'),
    AssignmentRule(id: 'rule_214', keyword: 'DEBITO OPERACION EN SUPERNET O SMS T (Despedida Tecnología)', categoryId: '13'),
    AssignmentRule(id: 'rule_215', keyword: 'DEBITO OPERACION EN SUPERNET O SMS T(Emergencia León)', categoryId: '10'),
    AssignmentRule(id: 'rule_216', keyword: 'Naturaleza Fr', categoryId: '6'),
  ];
  
  // --- PERSISTENCE ---
  
  // --- PERSISTENCE ---
  
  Future<void> loadData() async {
    try {
      // Load Settings
      final settingsData = await StorageService.instance.load('settings');
      if (settingsData != null) {
        _exchangeRate = settingsData['rate'] ?? 42.5;
      }
      
      // Load Categories
      final catData = await StorageService.instance.load('categories');
      if (catData != null && catData['categories'] != null) {
         _categories = (catData['categories'] as List)
            .map((e) => Category.fromJson(e))
            .toList();
      }

      // Load Rules
      final rulesData = await StorageService.instance.load('rules');
      if (rulesData != null && rulesData['rules'] != null) {
        _rules = (rulesData['rules'] as List)
            .map((e) => AssignmentRule.fromJson(e))
            .toList();
      }

      notifyListeners();
      
      // If first run (defaults), save them to persist immediately
      if (catData == null) await _saveCategories();
      if (rulesData == null) await _saveRules();
      if (settingsData == null) await _saveSettings();

    } catch (e) {
      print('Error loading config: $e');
    }
  }

  Future<void> _saveSettings() async {
    final data = {'rate': _exchangeRate};
    await StorageService.instance.save('settings', data);
  }

  Future<void> _saveCategories() async {
    final data = {'categories': _categories.map((c) => c.toJson()).toList()};
    await StorageService.instance.save('categories', data);
  }

  Future<void> _saveRules() async {
    final data = {'rules': _rules.map((r) => r.toJson()).toList()};
    await StorageService.instance.save('rules', data);
  }

  // Getters
  double get exchangeRate => _exchangeRate;
  List<Category> get categories => _categories;
  List<AssignmentRule> get rules => _rules;

  List<String> get incomeCategories => _categories
      .where((c) => c.type == CategoryType.income)
      .map((c) => c.name)
      .toList();

  List<String> get expenseCategories => _categories
      .where((c) => c.type == CategoryType.expense)
      .map((c) => c.name)
      .toList();

  // Setters & Logic
  void setExchangeRate(double value) {
    _exchangeRate = value;
    _saveSettings();
    notifyListeners();
  }

  void addCategory(String name, CategoryType type) {
    _categories.add(Category(id: const Uuid().v4(), name: name, type: type));
    _saveCategories();
    notifyListeners();
  }

  void removeCategory(String id) {
    _categories.removeWhere((c) => c.id == id);
    _rules.removeWhere((r) => r.categoryId == id);
    _saveCategories();
    _saveRules();
    notifyListeners();
  }

  void addRule(String keyword, String categoryId) {
    _rules.add(AssignmentRule(id: const Uuid().v4(), keyword: keyword, categoryId: categoryId));
    _saveRules();
    notifyListeners();
  }

  void removeRule(String id) {
    _rules.removeWhere((r) => r.id == id);
    _saveRules();
    notifyListeners();
  }

  String? getCategoryIdForDescription(String description) {
    for (var rule in _rules) {
      if (description.toLowerCase().contains(rule.keyword.toLowerCase())) {
        return rule.categoryId;
      }
    }
    return null;
  }

  Category? getCategoryById(String id) {
    try {
      return _categories.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  void editCategory(String id, String newName, CategoryType newType) {
    final index = _categories.indexWhere((c) => c.id == id);
    if (index != -1) {
      _categories[index].name = newName;
      _categories[index].type = newType;
      _saveCategories();
      notifyListeners();
    }
  }

  void editRule(String id, String newKeyword, String newCategoryId) {
    final index = _rules.indexWhere((r) => r.id == id);
    if (index != -1) {
      _rules[index].keyword = newKeyword;
      _rules[index].categoryId = newCategoryId;
      _saveRules();
      notifyListeners();
    }
  }

  // --- BACKUP & RESTORE ---
  DateTime? _lastBackup;
  DateTime? get lastBackup => _lastBackup;

  Future<void> checkLastBackup() async {
    _lastBackup = await StorageService.instance.getLastBackupDate();
    notifyListeners();
  }

  Future<void> performBackup() async {
    await StorageService.instance.createBackup();
    await checkLastBackup();
  }

  Future<void> performRestore(BuildContext context) async {
    await StorageService.instance.restoreBackup();
    
    // RECARGA EN CALIENTE
    await loadData(); // Reload config
    if (context.mounted) {
        await Provider.of<TransactionsProvider>(context, listen: false).loadData();
        await Provider.of<BudgetProvider>(context, listen: false).loadData();
    }
  }
}
