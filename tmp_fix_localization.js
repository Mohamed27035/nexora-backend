const fs = require("fs");

const replacements = {
  "C:\\Users\\Dell\\nexora_mobile\\lib\\screens\\transactions_screen.dart": [
    ["AnnulÃ©e", "Annulee"],
  ],
  "C:\\Users\\Dell\\nexora_mobile\\lib\\screens\\dashboard_screen.dart": [
    ["Indicateurs cles pour l'administration, la finance, la vÃ©rification d'identitÃ© et l'audit.", "Indicateurs cles pour l'administration, la finance, la verification d'identite et l'audit."],
    ['const Text(\n                "Scanner le QR du destinataire"', 'Text(\n                AppLanguage.t("Scanner le QR du destinataire", "مسح QR الخاص بالمستفيد")'],
    ['const Text(\n                "Placez le code QR dans le cadre pour remplir automatiquement le numero du destinataire."', 'Text(\n                AppLanguage.t("Placez le code QR dans le cadre pour remplir automatiquement le numero du destinataire.", "ضع رمز QR داخل الإطار لملء رقم المستفيد تلقائيًا.")'],
    ['child: Text("Fermer")', 'child: Text(AppLanguage.t("Fermer", "إغلاق"))'],
    ['const Text(\n                  "Recevoir de l\'argent"', 'Text(\n                  AppLanguage.t("Recevoir de l\'argent", "استقبال الأموال")'],
    ['const Text(\n                  "Partagez ce QR pour que l\'expediteur puisse remplir automatiquement votre numero."', 'Text(\n                  AppLanguage.t("Partagez ce QR pour que l\'expediteur puisse remplir automatiquement votre numero.", "شارك رمز QR هذا حتى يتمكن المرسل من تعبئة رقمك تلقائيًا.")'],
    ['_showMessage("Numero copie.");', '_showMessage(AppLanguage.t("Numero copie.", "تم نسخ الرقم."));'],
    ['label: const Text("Copier")', 'label: Text(AppLanguage.t("Copier", "نسخ"))'],
    ['? "Nouveau transfert"\n                          : "Nouveau retrait"', '? AppLanguage.t("Nouveau transfert", "تحويل جديد")\n                          : AppLanguage.t("Nouveau retrait", "سحب جديد")'],
    ['const Text(\n                      "Creez rapidement une operation sans quitter la page principale."', 'Text(\n                      AppLanguage.t("Creez rapidement une operation sans quitter la page principale.", "أنشئ عملية بسرعة دون مغادرة الصفحة الرئيسية.")'],
    ['decoration: const InputDecoration(labelText: "Montant (MRU)")', 'decoration: InputDecoration(labelText: AppLanguage.t("Montant (MRU)", "المبلغ (MRU)"))'],
    ['labelText: "Numero du destinataire"', 'labelText: AppLanguage.t("Numero du destinataire", "رقم المستفيد")'],
    ['tooltip: "Scanner un QR"', 'tooltip: AppLanguage.t("Scanner un QR", "مسح QR")'],
    ['decoration: const InputDecoration(\n                        labelText: "Note",\n                        hintText: "Note optionnelle",\n                      )', 'decoration: InputDecoration(\n                        labelText: AppLanguage.t("Note", "ملاحظة"),\n                        hintText: AppLanguage.t("Note optionnelle", "ملاحظة اختيارية"),\n                      )'],
    ['label: Text(submitting ? "Traitement..." : "Valider")', 'label: Text(submitting ? AppLanguage.t("Traitement...", "جارٍ المعالجة...") : AppLanguage.t("Valider", "تأكيد"))'],
    ['label: "Transfert"', 'label: AppLanguage.t("Transfert", "تحويل")'],
    ['label: "Retrait"', 'label: AppLanguage.t("Retrait", "سحب")'],
    ['label: "Mon QR"', 'label: AppLanguage.t("Mon QR", "رمز QR الخاص بي")'],
    ['const Text(\n                  "Compte inactif"', 'Text(\n                  AppLanguage.t("Compte inactif", "حساب غير نشط")'],
    ['const Text(\n            "Vous pouvez consulter l\'application, mais les services financiers restent bloques jusqu\'a la validation de votre identite par l\'administrateur."', 'Text(\n            AppLanguage.t("Vous pouvez consulter l\'application, mais les services financiers restent bloques jusqu\'a la validation de votre identite par l\'administrateur.", "يمكنك تصفح التطبيق، لكن الخدمات المالية تبقى معطلة إلى حين اعتماد هويتك من طرف المسؤول.")'],
    ['label: const Text("Completer la verification d\'identite")', 'label: Text(AppLanguage.t("Completer la verification d\'identite", "إكمال التحقق من الهوية"))'],
    ['const Text(\n            "Statistiques avancees"', 'Text(\n            AppLanguage.t("Statistiques avancees", "إحصائيات متقدمة")'],
    ['? "Indicateurs cles pour l\'administration, la finance, la verification d\'identite et l\'audit."\n                : "Resume rapide des statistiques disponibles sur votre tableau de bord."', '? AppLanguage.t("Indicateurs cles pour l\'administration, la finance, la verification d\'identite et l\'audit.", "مؤشرات أساسية للإدارة والمالية والتحقق من الهوية والتدقيق.")\n                : AppLanguage.t("Resume rapide des statistiques disponibles sur votre tableau de bord.", "ملخص سريع للإحصائيات المتاحة في لوحة التحكم الخاصة بك.")'],
    ['const Text(\n              "Aucune statistique detaillee"', 'Text(\n              AppLanguage.t("Aucune statistique detaillee", "لا توجد إحصائيات تفصيلية")'],
  ],
  "C:\\Users\\Dell\\nexora_mobile\\lib\\screens\\about_screen.dart": [
    ["children: const [", "children: ["],
  ],
  "C:\\Users\\Dell\\nexora_mobile\\lib\\screens\\audit\\audit_detail_screen.dart": [
    ['tr("Actor", "المنفذ")', 'tr("Auteur", "المنفذ")'],
    ['tr("Actor Email", "بريد المنفذ")', 'tr("Email de l\'auteur", "بريد المنفذ")'],
    ['tr("Sensitive", "حساس")', 'tr("Sensible", "حساس")'],
    ['tr("Suspicious", "مشبوه")', 'tr("Suspect", "مشبوه")'],
    ['tr("Yes", "نعم")', 'tr("Oui", "نعم")'],
    ['tr("No", "لا")', 'tr("Non", "لا")'],
    ['tr("Entity Type", "نوع الكيان")', 'tr("Type d\'entite", "نوع الكيان")'],
    ['tr("Entity ID", "معرف الكيان")', 'tr("Identifiant de l\'entite", "معرف الكيان")'],
    ['tr("Target", "الهدف")', 'tr("Cible", "الهدف")'],
    ['tr("Metadata", "البيانات الوصفية")', 'tr("Metadonnees", "البيانات الوصفية")'],
  ],
  "C:\\Users\\Dell\\nexora_mobile\\lib\\screens\\audit\\audit_logs_screen.dart": [
    ["Tous les journaux d\\'audit", "Tous les journaux d'audit"],
    ["Filtres d\\'audit", "Filtres d'audit"],
    ['tr("Search action, user, target, entity...", "ابحث بالفعل أو المستخدم أو الهدف أو الكيان...")', 'tr("Rechercher par action, utilisateur, cible ou entite...", "ابحث بالفعل أو المستخدم أو الهدف أو الكيان...")'],
    ['tr("Actors", "الفاعلون")', 'tr("Acteurs", "الفاعلون")'],
  ],
  "C:\\Users\\Dell\\nexora_mobile\\lib\\screens\\admin\\kyc_review_screen.dart": [
    ["Prenom du pÃ¨re", "Prenom du pere"],
  ],
  "C:\\Users\\Dell\\nexora_mobile\\lib\\screens\\kyc_screen.dart": [
    ["Prenom du pÃ¨re", "Prenom du pere"],
    ['appBar: AppBar(title: const Text("Verification identite"))', 'appBar: AppBar(title: Text(AppLanguage.t("Verification identite", "التحقق من الهوية")))'],
    ['title: Text(AppLanguage.t("Demande deja en attente", "طلب موجود مسبقًا")),\n          content: const Text(', 'title: Text(AppLanguage.t("Demande deja en attente", "طلب موجود مسبقًا")),\n          content: Text(AppLanguage.t('],
    ['"Une demande de verification d\'identite est deja en attente. Voulez-vous la mettre a jour avec les nouvelles images et les nouvelles informations OCR ?"', '"Une demande de verification d\'identite est deja en attente. Voulez-vous la mettre a jour avec les nouvelles images et les nouvelles informations OCR ?", "يوجد طلب تحقق من الهوية قيد الانتظار. هل تريد تحديثه بالصور الجديدة وبيانات OCR الجديدة؟")'],
    ['title: "Document d\'identite"', 'title: AppLanguage.t("Document d\'identite", "بطاقة التعريف")'],
    ['title: "Selfie"', 'title: AppLanguage.t("Selfie", "صورة سلفي")'],
    ['? "Verification approuvee"\n                                  : isPending\n                                  ? "Mettre a jour la verification"\n                                  : "Envoyer la verification"', '? AppLanguage.t("Verification approuvee", "تم قبول التحقق")\n                                  : isPending\n                                  ? AppLanguage.t("Mettre a jour la verification", "تحديث التحقق")\n                                  : AppLanguage.t("Envoyer la verification", "إرسال التحقق")'],
    ['const Text(\n          "OCR local"', 'Text(\n          AppLanguage.t("OCR local", "OCR المحلي")'],
    ['const Text(\n            "Statut de la verification"', 'Text(\n            AppLanguage.t("Statut de la verification", "حالة التحقق")'],
    ['"APPROVED" => "Votre identite a ete validee.",', '"APPROVED" => AppLanguage.t("Votre identite a ete validee.", "تم اعتماد هويتك."),'],
    ['"PENDING" => "Votre demande est en cours de revision.",', '"PENDING" => AppLanguage.t("Votre demande est en cours de revision.", "طلبك قيد المراجعة."),'],
    ['"REJECTED" => "Votre demande a ete rejetee. Verifiez la note.",', '"REJECTED" => AppLanguage.t("Votre demande a ete rejetee. Verifiez la note.", "تم رفض طلبك. يرجى مراجعة الملاحظة."),'],
    ['_ => "Aucune demande de verification d\'identite n\'a encore ete envoyee.",', '_ => AppLanguage.t("Aucune demande de verification d\'identite n\'a encore ete envoyee.", "لم يتم إرسال أي طلب تحقق من الهوية بعد."),'],
    ['"Note: ${kycData!["review_note"]}"', 'AppLanguage.t("Note", "ملاحظة") + ": ${kycData![\"review_note\"]}"'],
    ['label: Text(image == null ? "Ajouter" : "Changer")', 'label: Text(image == null ? AppLanguage.t("Ajouter", "إضافة") : AppLanguage.t("Changer", "تغيير"))'],
    ['const Text(\n          "Informations OCR enregistrees"', 'Text(\n          AppLanguage.t("Informations OCR enregistrees", "معلومات OCR المحفوظة")'],
    ['readyText: "Les informations OCR enregistrees sont disponibles.",', 'readyText: AppLanguage.t("Les informations OCR enregistrees sont disponibles.", "معلومات OCR المحفوظة متاحة."),'],
    ['pendingText: "Les informations OCR enregistrees sont incompletes.",', 'pendingText: AppLanguage.t("Les informations OCR enregistrees sont incompletes.", "معلومات OCR المحفوظة غير مكتملة."),'],
    ['title: "Confiance extraction",', 'title: AppLanguage.t("Confiance extraction", "ثقة الاستخراج"),'],
    ['_infoTile("NNI", kycData!["nni"]),', '_infoTile(AppLanguage.t("NNI", "الرقم الوطني"), kycData!["nni"]),'],
    ['_infoTile("Prenom", kycData!["prenom"]),', '_infoTile(AppLanguage.t("Prenom", "الاسم"), kycData!["prenom"]),'],
    ['_infoTile("Prenom du pere", kycData!["prenom_pere"]),', '_infoTile(AppLanguage.t("Prenom du pere", "اسم الأب"), kycData!["prenom_pere"]),'],
    ['_infoTile("Nom de famille", kycData!["nom_famille"]),', '_infoTile(AppLanguage.t("Nom de famille", "اسم العائلة"), kycData!["nom_famille"]),'],
    ['_infoTile("Sexe", kycData!["sexe"]),', '_infoTile(AppLanguage.t("Sexe", "الجنس"), kycData!["sexe"]),'],
    ['_infoTile("Date de naissance", kycData!["date_naissance"]),', '_infoTile(AppLanguage.t("Date de naissance", "تاريخ الميلاد"), kycData!["date_naissance"]),'],
    ['_infoTile("Lieu de naissance", kycData!["lieu_naissance"]),', '_infoTile(AppLanguage.t("Lieu de naissance", "مكان الميلاد"), kycData!["lieu_naissance"]),'],
    ['return "NNI";', 'return AppLanguage.t("NNI", "الرقم الوطني");'],
    ['return "Prenom";', 'return AppLanguage.t("Prenom", "الاسم");'],
    ['return "Prenom du pere";', 'return AppLanguage.t("Prenom du pere", "اسم الأب");'],
    ['return "Nom de famille";', 'return AppLanguage.t("Nom de famille", "اسم العائلة");'],
    ['return "Sexe";', 'return AppLanguage.t("Sexe", "الجنس");'],
    ['return "Date de naissance";', 'return AppLanguage.t("Date de naissance", "تاريخ الميلاد");'],
    ['return "Lieu de naissance";', 'return AppLanguage.t("Lieu de naissance", "مكان الميلاد");'],
    ['const Text("OCR local")', 'Text(AppLanguage.t("OCR local", "OCR المحلي"))'],
  ],
};

for (const [file, pairs] of Object.entries(replacements)) {
  let text = fs.readFileSync(file, "utf8");
  const original = text;
  for (const [oldValue, newValue] of pairs) {
    text = text.split(oldValue).join(newValue);
  }
  if (text !== original) {
    fs.writeFileSync(file, text, "utf8");
    console.log(`updated: ${file}`);
  }
}
