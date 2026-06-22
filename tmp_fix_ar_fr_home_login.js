const fs = require('fs');

function replaceRegex(content, replacements, file) {
  let updated = content;
  for (const [pattern, to] of replacements) {
    if (!pattern.test(updated)) {
      console.warn(`[warn] regex not found in ${file}: ${pattern}`);
      continue;
    }
    updated = updated.replace(pattern, to);
  }
  return updated;
}

const loginFile = String.raw`C:\Users\Dell\nexora_mobile\lib\screens\login_screen.dart`;
let login = fs.readFileSync(loginFile, 'utf8');
login = login
  .split(/\r?\n/)
  .filter((line) => !/Utilisez bient[oô]t/.test(line))
  .join('\n');
login = login.replace(
  /Text\(AppLanguage\.t\('Connexion entreprise', 'دخول المؤسسة'\), style: const TextStyle\(color: AppColors\.text, fontWeight: FontWeight\.w900, fontSize: 15\)\),\s*const SizedBox\(height: 12\),/g,
  `Text(AppLanguage.t('Connexion entreprise', 'دخول المؤسسة'), style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w900, fontSize: 15)),
                const SizedBox(height: 12),`,
);
login = login.replace(
  `Text(AppLanguage.t('Connexion entreprise', 'دخول المؤسسة'), style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w900, fontSize: 15)),                const SizedBox(height: 12),`,
  `Text(AppLanguage.t('Connexion entreprise', 'دخول المؤسسة'), style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w900, fontSize: 15)),
                const SizedBox(height: 12),`,
);
fs.writeFileSync(loginFile, login, 'utf8');
console.log(`updated ${loginFile}`);

const dashboardFile = String.raw`C:\Users\Dell\nexora_mobile\lib\screens\dashboard_screen.dart`;
let dashboard = fs.readFileSync(dashboardFile, 'utf8');
dashboard = replaceRegex(
  dashboard,
  [
    [/tooltip: _hideBalance \? "Afficher le solde" : "Masquer le solde",/g, `tooltip: AppLanguage.t(_hideBalance ? "Afficher le solde" : "Masquer le solde", _hideBalance ? "إظهار الرصيد" : "إخفاء الرصيد"),`],
    [/_hideBalance \? "Solde masque" : "Solde disponible",/g, `AppLanguage.t(_hideBalance ? "Solde masque" : "Solde disponible", _hideBalance ? "الرصيد مخفي" : "الرصيد المتاح"),`],
    [/AppLanguage\.t\(\s*"Rapports - Audit - Administration",\s*".*?"\s*\)/g, `AppLanguage.t("Rapports - Audit - Administration", "التقارير - التدقيق - الإدارة")`],
    [/AppLanguage\.t\(AppLanguage\.t\("Taux d'approbation", "معدل القبول"\), "معدل القبول"\)/g, `AppLanguage.t("Taux d'approbation", "معدل القبول")`],
    [/AppLanguage\.t\(AppLanguage\.t\("Score de risque", "درجة المخاطر"\), "درجة المخاطر"\)/g, `AppLanguage.t("Score de risque", "درجة المخاطر")`],
    [/AppLanguage\.t\(AppLanguage\.t\("En attente", "قيد الانتظار"\), "قيد الانتظار"\)/g, `AppLanguage.t("En attente", "قيد الانتظار")`],
    [/AppLanguage\.t\(AppLanguage\.t\("Rejetees", "مرفوضة"\), "مرفوضة"\)/g, `AppLanguage.t("Rejetees", "مرفوضة")`],
    [/AppLanguage\.t\(AppLanguage\.t\("Visualisation locale des montants recents\.", "عرض محلي للمبالغ الأخيرة\."\), "عرض محلي للمبالغ الأخيرة\."\)/g, `AppLanguage.t("Visualisation locale des montants recents.", "عرض محلي للمبالغ الأخيرة.")`],
    [/AppLanguage\.t\(AppLanguage\.t\("Statistiques avancees", "إحصاءات متقدمة"\), "إحصاءات متقدمة"\)/g, `AppLanguage.t("Statistiques avancees", "إحصاءات متقدمة")`],
    [/AppLanguage\.t\(AppLanguage\.t\("Glissez horizontalement pour voir plus d'indicateurs", "اسحب أفقيًا لعرض المزيد من المؤشرات"\), "اسحب أفقيًا لعرض المزيد من المؤشرات"\)/g, `AppLanguage.t("Glissez horizontalement pour voir plus d'indicateurs", "اسحب أفقيًا لعرض المزيد من المؤشرات")`],
    [/AppLanguage\.t\(AppLanguage\.t\("Base sur les transactions deja chargees\.", "بناءً على المعاملات المحملة سابقًا\."\), "بناءً على المعاملات المحملة سابقًا\."\)/g, `AppLanguage.t("Base sur les transactions deja chargees.", "بناءً على المعاملات المحملة سابقًا.")`],
    [/AppLanguage\.t\(AppLanguage\.t\("Calcule selon le nombre d'alertes actives\.", "يُحتسب حسب عدد التنبيهات النشطة\."\), "يُحتسب حسب عدد التنبيهات النشطة\."\)/g, `AppLanguage.t("Calcule selon le nombre d'alertes actives.", "يُحتسب حسب عدد التنبيهات النشطة.")`],
    [/AppLanguage\.t\(AppLanguage\.t\("Transactions en cours de traitement\.", "معاملات ما زالت قيد المعالجة\."\), "معاملات ما زالت قيد المعالجة\."\)/g, `AppLanguage.t("Transactions en cours de traitement.", "معاملات ما زالت قيد المعالجة.")`],
    [/AppLanguage\.t\(AppLanguage\.t\("Operations annulees ou refusees\.", "عمليات ملغاة أو مرفوضة\."\), "عمليات ملغاة أو مرفوضة\."\)/g, `AppLanguage.t("Operations annulees ou refusees.", "عمليات ملغاة أو مرفوضة.")`],
    [/AppLanguage\.t\(AppLanguage\.t\("Aucune donnee recente", "لا توجد بيانات حديثة"\), "لا توجد بيانات حديثة"\)/g, `AppLanguage.t("Aucune donnee recente", "لا توجد بيانات حديثة")`],
    [/AppLanguage\.t\(AppLanguage\.t\("Indicateurs cles pour l'administration, la finance, la verification d'identite et l'audit\.", "مؤشرات أساسية للإدارة والمالية والتحقق من الهوية والتدقيق\."\), "مؤشرات أساسية للإدارة والمالية والتحقق من الهوية والتدقيق\."\)/g, `AppLanguage.t("Indicateurs cles pour l'administration, la finance, la verification d'identite et l'audit.", "مؤشرات أساسية للإدارة والمالية والتحقق من الهوية والتدقيق.")`],
    [/AppLanguage\.t\(AppLanguage\.t\("Resume rapide des statistiques disponibles sur votre tableau de bord\.", "ملخص سريع للإحصاءات المتاحة في لوحة التحكم\."\), "ملخص سريع للإحصاءات المتاحة في لوحة التحكم\."\)/g, `AppLanguage.t("Resume rapide des statistiques disponibles sur votre tableau de bord.", "ملخص سريع للإحصاءات المتاحة في لوحة التحكم.")`],
    [/"Taux d'approbation"/g, `AppLanguage.t("Taux d'approbation", "معدل القبول")`],
    [/"Base sur les transactions deja chargees\." /g, `"Base sur les transactions deja chargees."`],
    [/"Base sur les transactions deja chargees\."/g, `AppLanguage.t("Base sur les transactions deja chargees.", "بناءً على المعاملات المحملة سابقًا.")`],
    [/"Score de risque"/g, `AppLanguage.t("Score de risque", "درجة المخاطر")`],
    [/"Calcule selon le nombre d'alertes actives\."/g, `AppLanguage.t("Calcule selon le nombre d'alertes actives.", "يُحتسب حسب عدد التنبيهات النشطة.")`],
    [/"En attente"/g, `AppLanguage.t("En attente", "قيد الانتظار")`],
    [/"Transactions en cours de traitement\."/g, `AppLanguage.t("Transactions en cours de traitement.", "معاملات ما زالت قيد المعالجة.")`],
    [/"Rejetees"/g, `AppLanguage.t("Rejetees", "مرفوضة")`],
    [/"Operations annulees ou refusees\."/g, `AppLanguage.t("Operations annulees ou refusees.", "عمليات ملغاة أو مرفوضة.")`],
    [/"Visualisation locale des montants recents\."/g, `AppLanguage.t("Visualisation locale des montants recents.", "عرض محلي للمبالغ الأخيرة.")`],
    [/"Aucune donnee recente"/g, `AppLanguage.t("Aucune donnee recente", "لا توجد بيانات حديثة")`],
    [/"Statistiques avancees"/g, `AppLanguage.t("Statistiques avancees", "إحصاءات متقدمة")`],
    [/"Indicateurs cles pour l'administration, la finance, la verification d'identite et l'audit\."/g, `AppLanguage.t("Indicateurs cles pour l'administration, la finance, la verification d'identite et l'audit.", "مؤشرات أساسية للإدارة والمالية والتحقق من الهوية والتدقيق.")`],
    [/"Resume rapide des statistiques disponibles sur votre tableau de bord\."/g, `AppLanguage.t("Resume rapide des statistiques disponibles sur votre tableau de bord.", "ملخص سريع للإحصاءات المتاحة في لوحة التحكم.")`],
    [/"Glissez horizontalement pour voir plus d'indicateurs"/g, `AppLanguage.t("Glissez horizontalement pour voir plus d'indicateurs", "اسحب أفقيًا لعرض المزيد من المؤشرات")`],
    [/return "Approuvee";/g, `return AppLanguage.t("Approuvee", "مقبولة");`],
    [/return "Rejetee";/g, `return AppLanguage.t("Rejetee", "مرفوضة");`],
    [/return "En attente";/g, `return AppLanguage.t("En attente", "قيد الانتظار");`],
    [/return "Echouee";/g, `return AppLanguage.t("Echouee", "فشلت");`],
    [/return "Annulee";/g, `return AppLanguage.t("Annulee", "ملغاة");`],
    [/return "Reussie";/g, `return AppLanguage.t("Reussie", "ناجحة");`],
    [/return "Depot";/g, `return AppLanguage.t("Depot", "إيداع");`],
    [/return "Retrait";/g, `return AppLanguage.t("Retrait", "سحب");`],
    [/return "Transfert";/g, `return AppLanguage.t("Transfert", "تحويل");`],
    [/return type\.isEmpty \? "Transaction" : type;/g, `return type.isEmpty ? AppLanguage.t("Transaction", "معاملة") : type;`],
    [/AppLanguage\.t\(\s*"Pilotage global des utilisateurs, de la verification d'identite et des operations\.",\s*".*?"\s*\)/g, `AppLanguage.t("Pilotage global des utilisateurs, de la verification d'identite et des operations.", "إدارة شاملة للمستخدمين وعمليات التحقق من الهوية والخدمات المالية.")`],
    [/AppLanguage\.t\(\s*"Suivi des traces, des alertes et de la conformite\.",\s*".*?"\s*\)/g, `AppLanguage.t("Suivi des traces, des alertes et de la conformite.", "متابعة السجلات والتنبيهات والامتثال.")`],
    [/AppLanguage\.t\(\s*"Controle des mouvements financiers et des validations\.",\s*".*?"\s*\)/g, `AppLanguage.t("Controle des mouvements financiers et des validations.", "مراقبة الحركات المالية وعمليات المصادقة.")`],
    [/AppLanguage\.t\(\s*"Accedez rapidement a vos operations et a votre espace client\.",\s*".*?"\s*\)/g, `AppLanguage.t("Accedez rapidement a vos operations et a votre espace client.", "يمكنك الوصول بسرعة إلى عملياتك ومساحتك الشخصية.")`],
    [/AppLanguage\.t\(\s*"Votre compte reste consultatif jusqu'a validation de votre identite\.",\s*".*?"\s*\)/g, `AppLanguage.t("Votre compte reste consultatif jusqu'a validation de votre identite.", "يبقى حسابك في وضع الاستعراض حتى يتم التحقق من هويتك.")`],
    [/return "Vue unifiee des utilisateurs, des transactions, du reporting et du controle de l'identite\.";/g, `return AppLanguage.t("Vue unifiee des utilisateurs, des transactions, du reporting et du controle de l'identite.", "عرض موحّد للمستخدمين والمعاملات والتقارير والتحكم في الهوية.");`],
    [/return "Acces centralise aux alertes, journaux d'audit et indicateurs de risque\.";/g, `return AppLanguage.t("Acces centralise aux alertes, journaux d'audit et indicateurs de risque.", "وصول مركزي إلى التنبيهات وسجلات التدقيق ومؤشرات المخاطر.");`],
    [/return "Suivez les flux financiers, les validations et les operations sensibles\.";/g, `return AppLanguage.t("Suivez les flux financiers, les validations et les operations sensibles.", "تابع التدفقات المالية وعمليات المصادقة والعمليات الحساسة.");`],
    [/\? "Suivez votre activite, vos mouvements et l'etat de votre compte depuis un espace unique\."\r?\n\s*: "Explorez l'application pendant que votre dossier d'identite est en cours de verification\.";/g, `? AppLanguage.t("Suivez votre activite, vos mouvements et l'etat de votre compte depuis un espace unique.", "تابع نشاطك وحركاتك وحالة حسابك من مساحة واحدة.")\n        : AppLanguage.t("Explorez l'application pendant que votre dossier d'identite est en cours de verification.", "تصفح التطبيق بينما ملف هويتك قيد التحقق.");`],
    [/return _canUseServices \? "Client actif" : "Client inactif";/g, `return AppLanguage.t(_canUseServices ? "Client actif" : "Client inactif", _canUseServices ? "عميل نشط" : "عميل غير نشط");`],
    [/return "Administrateur";/g, `return AppLanguage.t("Administrateur", "مدير النظام");`],
    [/return "Auditeur";/g, `return AppLanguage.t("Auditeur", "مدقق");`],
    [/return "Comptable";/g, `return AppLanguage.t("Comptable", "محاسب");`],
    [/return "Actif";/g, `return AppLanguage.t("Actif", "نشط");`],
  ],
  dashboardFile,
);
dashboard = dashboard
  .replace(
    `AppLanguage.t(AppLanguage.t(AppLanguage.t(AppLanguage.t(AppLanguage.t(_hideBalance ? "Solde masque" : "Solde disponible", _hideBalance ? "الرصيد مخفي" : "الرصيد المتاح"), _hideBalance ? "الرصيد مخفي" : "الرصيد المتاح"), _hideBalance ? "الرصيد مخفي" : "الرصيد المتاح"), _hideBalance ? "الرصيد مخفي" : "الرصيد المتاح"), _hideBalance ? "الرصيد مخفي" : "الرصيد المتاح")`,
    `AppLanguage.t(_hideBalance ? "Solde masque" : "Solde disponible", _hideBalance ? "الرصيد مخفي" : "الرصيد المتاح")`,
  )
  .replace(
    `AppLanguage.t(AppLanguage.t(AppLanguage.t("Base sur les transactions deja chargees.", "بناءً على المعاملات المحملة سابقًا."), "بناءً على المعاملات المحملة سابقًا."), "بناءً على المعاملات المحملة سابقًا.")`,
    `AppLanguage.t("Base sur les transactions deja chargees.", "بناءً على المعاملات المحملة سابقًا.")`,
  )
  .replace(
    `AppLanguage.t(AppLanguage.t(AppLanguage.t("Calcule selon le nombre d'alertes actives.", "يُحتسب حسب عدد التنبيهات النشطة."), "يُحتسب حسب عدد التنبيهات النشطة."), "يُحتسب حسب عدد التنبيهات النشطة.")`,
    `AppLanguage.t("Calcule selon le nombre d'alertes actives.", "يُحتسب حسب عدد التنبيهات النشطة.")`,
  )
  .replace(
    `AppLanguage.t(AppLanguage.t(AppLanguage.t("En attente", "قيد الانتظار"), "قيد الانتظار"), "قيد الانتظار")`,
    `AppLanguage.t("En attente", "قيد الانتظار")`,
  )
  .replace(
    `AppLanguage.t(AppLanguage.t(AppLanguage.t("Transactions en cours de traitement.", "معاملات ما زالت قيد المعالجة."), "معاملات ما زالت قيد المعالجة."), "معاملات ما زالت قيد المعالجة.")`,
    `AppLanguage.t("Transactions en cours de traitement.", "معاملات ما زالت قيد المعالجة.")`,
  )
  .replace(
    `AppLanguage.t(AppLanguage.t(AppLanguage.t("Operations annulees ou refusees.", "عمليات ملغاة أو مرفوضة."), "عمليات ملغاة أو مرفوضة."), "عمليات ملغاة أو مرفوضة.")`,
    `AppLanguage.t("Operations annulees ou refusees.", "عمليات ملغاة أو مرفوضة.")`,
  )
  .replace(
    `AppLanguage.t(AppLanguage.t("Aucune donnee recente", "لا توجد بيانات حديثة"), "لا توجد بيانات حديثة")`,
    `AppLanguage.t("Aucune donnee recente", "لا توجد بيانات حديثة")`,
  )
  .replace(
    `AppLanguage.t(AppLanguage.t(AppLanguage.t("Indicateurs cles pour l'administration, la finance, la verification d'identite et l'audit.", "مؤشرات أساسية للإدارة والمالية والتحقق من الهوية والتدقيق."), "مؤشرات أساسية للإدارة والمالية والتحقق من الهوية والتدقيق."), "مؤشرات أساسية للإدارة والمالية والتحقق من الهوية والتدقيق.")`,
    `AppLanguage.t("Indicateurs cles pour l'administration, la finance, la verification d'identite et l'audit.", "مؤشرات أساسية للإدارة والمالية والتحقق من الهوية والتدقيق.")`,
  )
  .replace(
    `AppLanguage.t(AppLanguage.t(AppLanguage.t("Resume rapide des statistiques disponibles sur votre tableau de bord.", "ملخص سريع للإحصاءات المتاحة في لوحة التحكم."), "ملخص سريع للإحصاءات المتاحة في لوحة التحكم."), "ملخص سريع للإحصاءات المتاحة في لوحة التحكم.")`,
    `AppLanguage.t("Resume rapide des statistiques disponibles sur votre tableau de bord.", "ملخص سريع للإحصاءات المتاحة في لوحة التحكم.")`,
  )
  .replace(
    /AppLanguage\.t\(AppLanguage\.t\(AppLanguage\.t\("Taux d'approbation", "معدل القبول"\), "معدل القبول"\), "معدل القبول"\)/g,
    `AppLanguage.t("Taux d'approbation", "معدل القبول")`,
  )
  .replace(
    /AppLanguage\.t\(AppLanguage\.t\(AppLanguage\.t\("Score de risque", "درجة المخاطر"\), "درجة المخاطر"\), "درجة المخاطر"\)/g,
    `AppLanguage.t("Score de risque", "درجة المخاطر")`,
  )
  .replace(
    /AppLanguage\.t\(AppLanguage\.t\(AppLanguage\.t\("Rejetees", "مرفوضة"\), "مرفوضة"\), "مرفوضة"\)/g,
    `AppLanguage.t("Rejetees", "مرفوضة")`,
  )
  .replace(
    /AppLanguage\.t\(AppLanguage\.t\(AppLanguage\.t\("Visualisation locale des montants recents\.", "عرض محلي للمبالغ الأخيرة\."\), "عرض محلي للمبالغ الأخيرة\."\), "عرض محلي للمبالغ الأخيرة\."\)/g,
    `AppLanguage.t("Visualisation locale des montants recents.", "عرض محلي للمبالغ الأخيرة.")`,
  )
  .replace(
    /AppLanguage\.t\(AppLanguage\.t\(AppLanguage\.t\("Statistiques avancees", "إحصاءات متقدمة"\), "إحصاءات متقدمة"\), "إحصاءات متقدمة"\)/g,
    `AppLanguage.t("Statistiques avancees", "إحصاءات متقدمة")`,
  )
  .replace(
    /AppLanguage\.t\(AppLanguage\.t\(AppLanguage\.t\("Glissez horizontalement pour voir plus d'indicateurs", "اسحب أفقيًا لعرض المزيد من المؤشرات"\), "اسحب أفقيًا لعرض المزيد من المؤشرات"\), "اسحب أفقيًا لعرض المزيد من المؤشرات"\)/g,
    `AppLanguage.t("Glissez horizontalement pour voir plus d'indicateurs", "اسحب أفقيًا لعرض المزيد من المؤشرات")`,
  );
fs.writeFileSync(dashboardFile, dashboard, 'utf8');
console.log(`updated ${dashboardFile}`);
