const fs = require('fs');

const file = String.raw`C:\Users\Dell\nexora_mobile\lib\screens\dashboard_screen.dart`;
const lines = fs.readFileSync(file, 'utf8').split(/\r?\n/);

function setLine(n, value) {
  if (n - 1 < lines.length) lines[n - 1] = value;
}

setLine(1383, '                ? Center(');
setLine(1384, '                    child: Text(');
setLine(1385, '                      AppLanguage.t("Aucune donnee recente", "لا توجد بيانات حديثة"),');
setLine(1386, '                      style: const TextStyle(color: _muted),');
setLine(1387, '                    ),');
setLine(1388, '                  )');

setLine(1454, '            Text(');
setLine(1455, '              AppLanguage.t("Aucune statistique detaillee", "لا توجد إحصاءات مفصلة"),');
setLine(1456, '              style: const TextStyle(color: _muted),');
setLine(1457, '            )');

fs.writeFileSync(file, lines.join('\n'), 'utf8');
console.log(`forced const fix ${file}`);
