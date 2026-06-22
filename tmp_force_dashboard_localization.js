const fs = require('fs');

const file = String.raw`C:\Users\Dell\nexora_mobile\lib\screens\dashboard_screen.dart`;
const lines = fs.readFileSync(file, 'utf8').split(/\r?\n/);

function setLine(n, value) {
  if (n - 1 < lines.length) lines[n - 1] = value;
}

setLine(1018, '              AppLanguage.t(_hideBalance ? "Solde masque" : "Solde disponible", _hideBalance ? "الرصيد مخفي" : "الرصيد المتاح"),');
setLine(1028, '              "Rapports - Audit - Administration",');
setLine(1029, '              "التقارير - التدقيق - الإدارة",');

setLine(1230, '                AppLanguage.t("Taux d\'approbation", "معدل القبول"),');
setLine(1232, '                AppLanguage.t("Base sur les transactions deja chargees.", "بناءً على المعاملات المحملة سابقًا."),');
setLine(1240, '                AppLanguage.t("Score de risque", "درجة المخاطر"),');
setLine(1242, '                AppLanguage.t("Calcule selon le nombre d\'alertes actives.", "يُحتسب حسب عدد التنبيهات النشطة."),');
setLine(1255, '                AppLanguage.t("En attente", "قيد الانتظار"),');
setLine(1257, '                AppLanguage.t("Transactions en cours de traitement.", "معاملات ما زالت قيد المعالجة."),');
setLine(1265, '                AppLanguage.t("Rejetees", "مرفوضة"),');
setLine(1267, '                AppLanguage.t("Operations annulees ou refusees.", "عمليات ملغاة أو مرفوضة."),');

setLine(1376, '            AppLanguage.t("Visualisation locale des montants recents.", "عرض محلي للمبالغ الأخيرة."),');
setLine(1385, '                      AppLanguage.t("Aucune donnee recente", "لا توجد بيانات حديثة"),');

setLine(1438, '            AppLanguage.t("Statistiques avancees", "إحصاءات متقدمة"),');
setLine(1448, '                ? AppLanguage.t("Indicateurs cles pour l\'administration, la finance, la verification d\'identite et l\'audit.", "مؤشرات أساسية للإدارة والمالية والتحقق من الهوية والتدقيق.")');
setLine(1449, '                : AppLanguage.t("Resume rapide des statistiques disponibles sur votre tableau de bord.", "ملخص سريع للإحصاءات المتاحة في لوحة التحكم."),');
setLine(1455, '              AppLanguage.t("Aucune statistique detaillee", "لا توجد إحصاءات مفصلة"),');
setLine(1463, '                  AppLanguage.t("Glissez horizontalement pour voir plus d\'indicateurs", "اسحب أفقيًا لعرض المزيد من المؤشرات"),');

setLine(2207, '        return AppLanguage.t("Approuvee", "مقبولة");');
setLine(2209, '        return AppLanguage.t("Rejetee", "مرفوضة");');
setLine(2211, '        return AppLanguage.t("En attente", "قيد الانتظار");');
setLine(2213, '        return AppLanguage.t("Echouee", "فشلت");');
setLine(2215, '        return AppLanguage.t("Annulee", "ملغاة");');
setLine(2217, '        return AppLanguage.t("Reussie", "ناجحة");');

setLine(2226, '        return AppLanguage.t("Depot", "إيداع");');
setLine(2228, '        return AppLanguage.t("Retrait", "سحب");');
setLine(2230, '        return AppLanguage.t("Transfert", "تحويل");');
setLine(2232, '        return type.isEmpty ? AppLanguage.t("Transaction", "معاملة") : type;');

setLine(2239, '        "Pilotage global des utilisateurs, de la verification d\'identite et des operations.",');
setLine(2240, '        "إدارة شاملة للمستخدمين وعمليات التحقق من الهوية والخدمات المالية.",');
setLine(2245, '        "Suivi des traces, des alertes et de la conformite.",');
setLine(2246, '        "متابعة السجلات والتنبيهات والامتثال.",');
setLine(2251, '        "Controle des mouvements financiers et des validations.",');
setLine(2252, '        "مراقبة الحركات المالية وعمليات المصادقة.",');
setLine(2257, '            "Accedez rapidement a vos operations et a votre espace client.",');
setLine(2258, '            "يمكنك الوصول بسرعة إلى عملياتك ومساحتك الشخصية.",');
setLine(2261, '            "Votre compte reste consultatif jusqu\'a validation de votre identite.",');
setLine(2262, '            "يبقى حسابك في وضع الاستعراض حتى يتم التحقق من هويتك.",');

setLine(2268, '      return AppLanguage.t("Vue unifiee des utilisateurs, des transactions, du reporting et du controle de l\'identite.", "عرض موحّد للمستخدمين والمعاملات والتقارير والتحكم في الهوية.");');
setLine(2271, '      return AppLanguage.t("Acces centralise aux alertes, journaux d\'audit et indicateurs de risque.", "وصول مركزي إلى التنبيهات وسجلات التدقيق ومؤشرات المخاطر.");');
setLine(2274, '      return AppLanguage.t("Suivez les flux financiers, les validations et les operations sensibles.", "تابع التدفقات المالية وعمليات المصادقة والعمليات الحساسة.");');
setLine(2277, '        ? AppLanguage.t("Suivez votre activite, vos mouvements et l\'etat de votre compte depuis un espace unique.", "تابع نشاطك وحركاتك وحالة حسابك من مساحة واحدة.")');
setLine(2278, '        : AppLanguage.t("Explorez l\'application pendant que votre dossier d\'identite est en cours de verification.", "تصفح التطبيق بينما ملف هويتك قيد التحقق.");');

setLine(2284, '        return AppLanguage.t("Administrateur", "مدير النظام");');
setLine(2286, '        return AppLanguage.t("Auditeur", "مدقق");');
setLine(2288, '        return AppLanguage.t("Comptable", "محاسب");');
setLine(2290, '        return AppLanguage.t(_canUseServices ? "Client actif" : "Client inactif", _canUseServices ? "عميل نشط" : "عميل غير نشط");');
setLine(2292, '        return AppLanguage.t("Actif", "نشط");');

fs.writeFileSync(file, lines.join('\n'), 'utf8');
console.log(`forced localization in ${file}`);
