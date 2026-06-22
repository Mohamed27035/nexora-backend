const fs = require('fs');

function replaceBlock(file, startMarker, endMarker, replacement) {
  const text = fs.readFileSync(file, 'utf8');
  const start = text.indexOf(startMarker);
  const end = text.indexOf(endMarker);
  if (start === -1 || end === -1 || end <= start) {
    throw new Error(`Could not find block markers in ${file}`);
  }
  const updated = text.slice(0, start) + replacement + text.slice(end);
  fs.writeFileSync(file, updated, 'utf8');
}

const profileFile = String.raw`C:\Users\Dell\nexora_mobile\lib\screens\profile_screen.dart`;
replaceBlock(
  profileFile,
  `  Widget _identityCard() {`,
  `  Widget _miniStat(String label, String value, Color color) {`,
`  Widget _identityCard() {
    return _sectionCard(
      title: tr("Nom et prenom", "الاسم الشخصي"),
      child: Column(
        children: [
          _field(tr("Nom", "اللقب"), nomController, Icons.badge_outlined),
          const SizedBox(height: 14),
          _field(tr("Prenom", "الاسم"), prenomController, Icons.person_outline),
          const SizedBox(height: 18),
          _sectionButton(
            onPressed: _isSaving("identity") ? null : saveIdentity,
            label: _isSaving("identity")
                ? tr("Enregistrement...", "جارٍ الحفظ...")
                : tr("Enregistrer le nom", "حفظ الاسم"),
          ),
        ],
      ),
    );
  }

  Widget _phoneCard() {
    return _sectionCard(
      title: tr("Numero de telephone", "رقم الهاتف"),
      child: Column(
        children: [
          _field(tr("Telephone", "الهاتف"), telephoneController, Icons.call_outlined),
          const SizedBox(height: 18),
          _sectionButton(
            onPressed: _isSaving("phone") ? null : savePhone,
            label: _isSaving("phone")
                ? tr("Enregistrement...", "جارٍ الحفظ...")
                : tr("Enregistrer le numero", "حفظ الرقم"),
          ),
        ],
      ),
    );
  }

  Widget _passwordCard() {
    return _sectionCard(
      title: tr("Mot de passe", "كلمة المرور"),
      child: Column(
        children: [
          _field(
            tr("Nouveau mot de passe", "كلمة المرور الجديدة"),
            passwordController,
            Icons.lock_outline,
            obscureText: true,
          ),
          const SizedBox(height: 14),
          _field(
            tr("Confirmer le mot de passe", "تأكيد كلمة المرور"),
            confirmPasswordController,
            Icons.verified_user_outlined,
            obscureText: true,
          ),
          const SizedBox(height: 18),
          _sectionButton(
            onPressed: _isSaving("password") ? null : savePassword,
            label: _isSaving("password")
                ? tr("Mise a jour...", "جارٍ التحديث...")
                : tr("Mettre a jour le mot de passe", "تحديث كلمة المرور"),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.surfaceSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (subtitle != null && subtitle.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(
                color: AppColors.muted,
                height: 1.45,
              ),
            ),
          ],
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

`)
;

const dashboardFile = String.raw`C:\Users\Dell\nexora_mobile\lib\screens\dashboard_screen.dart`;
let dashboard = fs.readFileSync(dashboardFile, 'utf8');
dashboard = dashboard.replace(
  `                ? const Center(
                    child: Text(
                      AppLanguage.t("Aucune donnee recente", "Ù„Ø§ ØªÙˆØ¬Ø¯ Ø¨ÙŠØ§Ù†Ø§Øª Ø­Ø¯ÙŠØ«Ø©"),
                      style: const TextStyle(color: _muted),
                    ),
                  )`,
  `                ? Center(
                    child: Text(
                      AppLanguage.t("Aucune donnee recente", "لا توجد بيانات حديثة"),
                      style: const TextStyle(color: _muted),
                    ),
                  )`,
);
dashboard = dashboard.replace(
  `          if (entries.isEmpty)
            const Text(
              AppLanguage.t("Aucune statistique detaillee", "Ù„Ø§ ØªÙˆØ¬Ø¯ Ø¥Ø­ØµØ§Ø¡Ø§Øª Ù…ÙØµÙ„Ø©"),
              style: const TextStyle(color: _muted),
            )`,
  `          if (entries.isEmpty)
            Text(
              AppLanguage.t("Aucune statistique detaillee", "لا توجد إحصاءات مفصلة"),
              style: const TextStyle(color: _muted),
            )`,
);
fs.writeFileSync(dashboardFile, dashboard, 'utf8');
console.log('repaired profile and dashboard');
