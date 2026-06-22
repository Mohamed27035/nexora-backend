const fs = require('fs');

const profileFile = String.raw`C:\Users\Dell\nexora_mobile\lib\screens\profile_screen.dart`;
let profile = fs.readFileSync(profileFile, 'utf8');
if (!profile.includes('Widget _sectionButton({')) {
  profile = profile.replace(
    `  Widget _miniStat(String label, String value, Color color) {`,
    `  Widget _sectionButton({
    required VoidCallback? onPressed,
    required String label,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) {`,
  );
}
fs.writeFileSync(profileFile, profile, 'utf8');

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

console.log('fixed remaining analyze issues');
