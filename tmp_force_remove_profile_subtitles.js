const fs = require('fs');

const file = String.raw`C:\Users\Dell\nexora_mobile\lib\screens\profile_screen.dart`;
const lines = fs.readFileSync(file, 'utf8').split(/\r?\n/);

function removeRange(start, end) {
  lines.splice(start - 1, end - start + 1);
}

function replaceLine(lineNumber, value) {
  if (lineNumber - 1 < lines.length) {
    lines[lineNumber - 1] = value;
  }
}

removeRange(508, 511);
removeRange(486, 489);
removeRange(462, 465);

replaceLine(531, '  Widget _sectionCard({');
replaceLine(532, '    required String title,');
replaceLine(533, '    String? subtitle,');
replaceLine(534, '    required Widget child,');
replaceLine(535, '  }) {');

replaceLine(555, '          if (subtitle != null && subtitle.trim().isNotEmpty) ...[');
replaceLine(556, '            const SizedBox(height: 8),');
replaceLine(557, '            Text(');
replaceLine(558, '              subtitle,');
replaceLine(559, '              style: const TextStyle(');
replaceLine(560, '                color: AppColors.muted,');
replaceLine(561, '                height: 1.45,');
replaceLine(562, '              ),');
replaceLine(563, '            ),');
replaceLine(564, '            const SizedBox(height: 18),');
replaceLine(565, '          ] else');
replaceLine(566, '            const SizedBox(height: 18),');

fs.writeFileSync(file, lines.join('\n'), 'utf8');
console.log(`forced update ${file}`);
