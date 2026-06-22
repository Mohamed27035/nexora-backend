const fs = require('fs');

const file = String.raw`C:\Users\Dell\nexora_mobile\lib\screens\profile_screen.dart`;
let text = fs.readFileSync(file, 'utf8');

text = text.replace(
  /title: tr\("Nom et prenom", "الاسم الشخصي"\),\s*subtitle: tr\(\s*"Modifiez votre identite sans toucher au numero ni au mot de passe\.",\s*"يمكن تعديل الاسم بشكل منفصل عن الرقم وكلمة المرور\.",\s*\),/m,
  `title: tr("Nom et prenom", "الاسم الشخصي"),`,
);

text = text.replace(
  /title: tr\("Numero de telephone", "رقم الهاتف"\),\s*subtitle: tr\(\s*"Le numero peut etre modifie tout seul, comme sur Facebook\.",\s*"يمكن تعديل الرقم وحده دون تغيير الاسم أو كلمة المرور\.",\s*\),/m,
  `title: tr("Numero de telephone", "رقم الهاتف"),`,
);

text = text.replace(
  /title: tr\("Mot de passe", "كلمة المرور"\),\s*subtitle: tr\(\s*"Changez le mot de passe separement, sans modifier les autres informations\.",\s*"يمكن تغيير كلمة المرور بشكل منفصل دون تعديل باقي المعلومات\.",\s*\),/m,
  `title: tr("Mot de passe", "كلمة المرور"),`,
);

text = text.replace(
  /Widget _sectionCard\(\{\s*required String title,\s*required String subtitle,\s*required Widget child,\s*\}\) \{/m,
  `Widget _sectionCard({
    required String title,
    String? subtitle,
    required Widget child,
  }) {`,
);

text = text.replace(
  /const SizedBox\(height: 8\),\s*Text\(\s*subtitle,\s*style: const TextStyle\(\s*color: AppColors\.muted,\s*height: 1\.45,\s*\),\s*\),\s*const SizedBox\(height: 18\),/m,
  `if (subtitle != null && subtitle.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(
                color: AppColors.muted,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
          ] else
            const SizedBox(height: 18),`,
);

fs.writeFileSync(file, text, 'utf8');
console.log(`updated ${file}`);
