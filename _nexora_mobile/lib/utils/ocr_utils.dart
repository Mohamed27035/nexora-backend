import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrUtils {
  static const Map<String, List<String>> _fieldAliases = {
    "nni": [
      "numero national d'identification",
      "numero national didentification",
      "national identification number",
      "numero national identification",
      "nni",
    ],
    "prenom": [
      "prenom/given name",
      "prenom given name",
      "given name",
      "prenom",
    ],
    "prenom_pere": [
      "prenom du pere/father's given name",
      "prenom du pere father's given name",
      "father's given name",
      "fathers given name",
      "prenom du pere",
    ],
    "nom_famille": [
      "nom de famille/surname",
      "nom de famille surname",
      "surname",
      "nom de famille",
    ],
    "sexe": [
      "sexe/sex",
      "sexe sex",
      "sex",
      "sexe",
    ],
    "date_naissance": [
      "date de naissance/date of birth",
      "date de naissance date of birth",
      "date of birth",
      "date de naissance",
    ],
    "lieu_naissance": [
      "lieu de naissance/place of birth",
      "lieu de naissance place of birth",
      "place of birth",
      "lieu de naissance",
    ],
  };

  static String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll("ÃƒÂ©", "e")
        .replaceAll("ÃƒÂ¨", "e")
        .replaceAll("ÃƒÂª", "e")
        .replaceAll("ÃƒÂ«", "e")
        .replaceAll("ÃƒÂ ", "a")
        .replaceAll("ÃƒÂ¢", "a")
        .replaceAll("ÃƒÂ®", "i")
        .replaceAll("ÃƒÂ¯", "i")
        .replaceAll("ÃƒÂ´", "o")
        .replaceAll("ÃƒÂ¹", "u")
        .replaceAll("ÃƒÂ»", "u")
        .replaceAll("ÃƒÂ§", "c")
        .replaceAll("â€™", "'")
        .replaceAll("ﬁ", "fi")
        .replaceAll("ﬂ", "fl")
        .replaceAll(RegExp(r"[^a-z0-9'/ -]+"), " ")
        .replaceAll(RegExp(r"\s+"), " ")
        .trim();
  }

  static String _cleanupValue(String value) {
    return value
        .replaceAll("|", "I")
        .replaceAll(" ,", ",")
        .replaceAll("ﬁ", "fi")
        .replaceAll("ﬂ", "fl")
        .replaceAll(RegExp(r"\s+"), " ")
        .trim()
        .replaceAll(RegExp(r"^[:\-\s]+|[:\-\s]+$"), "");
  }

  static bool _looksLikeName(String value) {
    final compact = _cleanupValue(value);
    if (compact.length < 2) return false;
    if (RegExp(r"\d").hasMatch(compact)) return false;
    return RegExp(r"^[A-Za-zÀ-ÿ' -]{2,}$").hasMatch(compact);
  }

  static bool _looksLikeNni(String value) {
    final compact = _normalizeNniCandidate(value).replaceAll(RegExp(r"\D"), "");
    return compact.length >= 8 && compact.length <= 14;
  }

  static bool _looksLikeDate(String value) {
    final compact = _cleanupValue(value);
    final patterns = [
      RegExp(r"^\d{1,2}\s+[A-Za-z]{3,}(?:/[A-Za-z]{3,})?\s+\d{4}$"),
      RegExp(r"^\d{1,2}[/-]\d{1,2}[/-]\d{4}$"),
      RegExp(r"^\d{4}[/-]\d{1,2}[/-]\d{1,2}$"),
    ];
    return patterns.any((pattern) => pattern.hasMatch(compact));
  }

  static bool _looksLikeSex(String value) {
    final upper = _cleanupValue(value).toUpperCase();
    return upper == "M" || upper == "F";
  }

  static String _normalizeNniCandidate(String value) {
    var cleaned = _cleanupValue(value).toUpperCase();
    const substitutions = {
      "O": "0",
      "Q": "0",
      "D": "0",
      "I": "1",
      "L": "1",
      "Z": "2",
      "S": "5",
      "B": "8",
      "G": "9",
    };
    substitutions.forEach((source, target) {
      cleaned = cleaned.replaceAll(source, target);
    });
    return cleaned;
  }

  static bool _lineMatchesFieldHint(String fieldName, String normalizedLine) {
    const hintGroups = {
      "nni": [
        ["ident"],
        ["nni", "nation", "num", "numero"],
      ],
      "prenom": [
        ["prenom", "prnom", "given", "gen"],
        ["name", "nane", "ane"],
      ],
      "prenom_pere": [
        ["pere", "prel", "father", "fath", "athe"],
        ["name", "nane", "ane"],
      ],
      "nom_famille": [
        ["famille", "fanlle", "surname", "surnae", "sur"],
      ],
      "sexe": [
        ["sex", "sexe", "sees"],
      ],
      "date_naissance": [
        ["date"],
        ["birth", "naiss", "nance"],
      ],
      "lieu_naissance": [
        ["place", "lieu"],
        ["birth", "naiss", "nance"],
      ],
    };

    final groups = hintGroups[fieldName] ?? const <List<String>>[];
    if (groups.isEmpty) return false;

    for (final group in groups) {
      final matchesAny = group.any((token) => normalizedLine.contains(token));
      if (!matchesAny) return false;
    }
    return true;
  }

  static bool _looksLikeLabel(String normalizedLine) {
    for (final aliases in _fieldAliases.values) {
      for (final alias in aliases) {
        if (normalizedLine.contains(alias)) return true;
      }
    }
    return false;
  }

  static bool _valueMatchesField(String fieldName, String value) {
    if (value.isEmpty) return false;
    switch (fieldName) {
      case "nni":
        return _looksLikeNni(value);
      case "prenom":
      case "prenom_pere":
      case "nom_famille":
      case "lieu_naissance":
        return _looksLikeName(value);
      case "date_naissance":
        return _looksLikeDate(value);
      case "sexe":
        return _looksLikeSex(value);
      default:
        return false;
    }
  }

  static String _extractInlineValue(String line, String alias) {
    final normalizedLine = _normalize(line);
    final index = normalizedLine.indexOf(alias);
    if (index == -1) return "";

    final safeIndex =
        (index + alias.length <= line.length) ? index + alias.length : line.length;
    var remainder = _cleanupValue(line.substring(safeIndex));
    if (remainder.isEmpty) return "";

    for (final separator in ["/", "  "]) {
      final parts = remainder
          .split(separator)
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();
      if (parts.length > 1) {
        remainder = parts.first;
        break;
      }
    }

    return _cleanupValue(remainder);
  }

  static String _extractValueAfterLabel(String line) {
    final parts = line.split(RegExp(r"[:;]\s*"));
    if (parts.length >= 2) {
      return _cleanupValue(parts.sublist(1).join(" "));
    }
    return "";
  }

  static String _extractFieldValue(
    String fieldName,
    List<String> lines,
    List<String> normalizedLines,
  ) {
    final aliases = _fieldAliases[fieldName] ?? const <String>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final normalizedLine = normalizedLines[i];

      for (final alias in aliases) {
        if (!normalizedLine.contains(alias)) continue;

        final inline = _extractInlineValue(line, alias);
        if (_valueMatchesField(fieldName, inline)) {
          return inline;
        }

        final afterLabel = _extractValueAfterLabel(line);
        if (_valueMatchesField(fieldName, afterLabel)) {
          return afterLabel;
        }

        for (var j = i + 1; j < lines.length && j <= i + 3; j++) {
          final candidate = _cleanupValue(lines[j]);
          final normalizedCandidate = normalizedLines[j];
          if (candidate.isEmpty) continue;
          if (_looksLikeLabel(normalizedCandidate)) break;

          if (_valueMatchesField(fieldName, candidate)) {
            return candidate;
          }

          if (j + 1 < lines.length) {
            final merged = _cleanupValue("$candidate ${lines[j + 1]}");
            if (_valueMatchesField(fieldName, merged)) {
              return merged;
            }
          }
        }
      }

      if (_lineMatchesFieldHint(fieldName, normalizedLine)) {
        for (var j = i + 1; j < lines.length && j <= i + 3; j++) {
          final candidate = _cleanupValue(lines[j]);
          if (_valueMatchesField(fieldName, candidate)) {
            return candidate;
          }
        }
      }
    }

    return "";
  }

  static String _fallbackSearch(String text, String fieldName) {
    final patterns = <String, List<RegExp>>{
      "nni": [
        RegExp(r"\b(\d{8,14})\b", caseSensitive: false),
        RegExp(r"(\d{10})", caseSensitive: false),
      ],
      "prenom": [
        RegExp(
          r"(?:prenom|given name)\s*[:\-]?\s*([A-Za-zÀ-ÿ' -]{2,})",
          caseSensitive: false,
        ),
      ],
      "prenom_pere": [
        RegExp(
          r"(?:father'?s given name|prenom du pere)\s*[:\-]?\s*([A-Za-zÀ-ÿ' -]{2,})",
          caseSensitive: false,
        ),
      ],
      "nom_famille": [
        RegExp(
          r"(?:nom de famille|surname)\s*[:\-]?\s*([A-Za-zÀ-ÿ' -]{2,})",
          caseSensitive: false,
        ),
      ],
      "sexe": [
        RegExp(r"(?:sexe|sex)\s*[:\-]?\s*([MF])\b", caseSensitive: false),
        RegExp(r"\b([MF])\b", caseSensitive: false),
      ],
      "date_naissance": [
        RegExp(
          r"\b(\d{1,2}\s+[A-Za-z]{3,}(?:/[A-Za-z]{3,})?\s+\d{4})\b",
          caseSensitive: false,
        ),
        RegExp(r"\b(\d{1,2}[/-]\d{1,2}[/-]\d{4})\b", caseSensitive: false),
        RegExp(r"\b(\d{4}[/-]\d{1,2}[/-]\d{1,2})\b", caseSensitive: false),
      ],
      "lieu_naissance": [
        RegExp(
          r"(?:lieu de naissance|place of birth)\s*[:\-]?\s*([A-Za-zÀ-ÿ' -]{2,})",
          caseSensitive: false,
        ),
      ],
    };

    for (final regex in patterns[fieldName] ?? const <RegExp>[]) {
      final match = regex.firstMatch(text);
      final value = _cleanupValue(match?.group(1) ?? "");
      if (fieldName == "nni") {
        final normalizedValue =
            _normalizeNniCandidate(value).replaceAll(RegExp(r"\D"), "");
        if (_valueMatchesField(fieldName, normalizedValue)) {
          return normalizedValue;
        }
      } else if (_valueMatchesField(fieldName, value)) {
        return value;
      }
    }

    return "";
  }

  static Future<String> recognizeText(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await recognizer.processImage(inputImage);
      return result.text;
    } finally {
      await recognizer.close();
    }
  }

  static Map<String, String> parseIdentityFields(String rawText) {
    final lines = rawText
        .replaceAll("\r", "\n")
        .split("\n")
        .map(_cleanupValue)
        .where((line) => line.isNotEmpty)
        .toList();
    final normalizedLines = lines.map(_normalize).toList();
    final joined = lines.join(" ");

    final out = <String, String>{};

    void put(String key, String value) {
      if (value.trim().isNotEmpty) {
        out[key] = value.trim();
      }
    }

    for (final fieldName in [
      "nni",
      "prenom",
      "prenom_pere",
      "nom_famille",
      "sexe",
      "date_naissance",
      "lieu_naissance",
    ]) {
      final extracted = _extractFieldValue(fieldName, lines, normalizedLines);
      put(fieldName, extracted.isNotEmpty ? extracted : _fallbackSearch(joined, fieldName));
    }

    for (var i = 0; i < normalizedLines.length; i++) {
      final normalizedLine = normalizedLines[i];

      if ((out["nni"] ?? "").isEmpty && normalizedLine.contains("identification")) {
        for (final candidate in lines.skip(i).take(3)) {
          if (_looksLikeNni(candidate)) {
            out["nni"] = _normalizeNniCandidate(candidate).replaceAll(RegExp(r"\D"), "");
            break;
          }
        }
      }

      if ((out["prenom"] ?? "").isEmpty &&
          (normalizedLine.contains("given name") || normalizedLine == "prenom")) {
        for (final candidate in lines.skip(i + 1).take(2)) {
          if (_looksLikeName(candidate)) {
            out["prenom"] = candidate;
            break;
          }
        }
      }

      if ((out["prenom_pere"] ?? "").isEmpty &&
          (normalizedLine.contains("father") || normalizedLine.contains("prenom du pere"))) {
        for (final candidate in lines.skip(i + 1).take(2)) {
          if (_looksLikeName(candidate)) {
            out["prenom_pere"] = candidate;
            break;
          }
        }
      }

      if ((out["nom_famille"] ?? "").isEmpty &&
          (normalizedLine.contains("surname") || normalizedLine.contains("nom de famille"))) {
        for (final candidate in lines.skip(i + 1).take(2)) {
          if (_looksLikeName(candidate)) {
            out["nom_famille"] = candidate;
            break;
          }
        }
      }

      if ((out["sexe"] ?? "").isEmpty &&
          (normalizedLine.contains("sex") || normalizedLine == "sexe")) {
        for (final candidate in lines.skip(i).take(3)) {
          final cleaned = _cleanupValue(candidate).toUpperCase();
          if (cleaned == "M" || cleaned == "F") {
            out["sexe"] = cleaned;
            break;
          }
        }
      }

      if ((out["date_naissance"] ?? "").isEmpty &&
          (normalizedLine.contains("date of birth") ||
              normalizedLine.contains("date de naissance"))) {
        for (final candidate in lines.skip(i).take(3)) {
          if (_looksLikeDate(candidate)) {
            out["date_naissance"] = candidate;
            break;
          }
        }
      }

      if ((out["lieu_naissance"] ?? "").isEmpty &&
          (normalizedLine.contains("place of birth") ||
              normalizedLine.contains("lieu de naissance"))) {
        for (final candidate in lines.skip(i + 1).take(2)) {
          if (_looksLikeName(candidate)) {
            out["lieu_naissance"] = candidate;
            break;
          }
        }
      }
    }

    if ((out["lieu_naissance"] ?? "").isEmpty) {
      for (final line in lines.reversed) {
        final normalizedLine = _normalize(line);
        if (_looksLikeName(line) &&
            !normalizedLine.contains("republique") &&
            !normalizedLine.contains("identite") &&
            !normalizedLine.contains("carte")) {
          out["lieu_naissance"] = line;
          break;
        }
      }
    }

    if ((out["nni"] ?? "").isNotEmpty) {
      out["nni"] = _normalizeNniCandidate(out["nni"]!).replaceAll(RegExp(r"\D"), "");
    }

    if ((out["sexe"] ?? "").isNotEmpty) {
      out["sexe"] = out["sexe"]!.toUpperCase();
    }

    return out;
  }

  static List<String> detectWarnings(Map<String, String> fields) {
    final warnings = <String>[];
    if ((fields["nni"] ?? "").isEmpty) {
      warnings.add("NNI non détecté");
    }
    if ((fields["prenom"] ?? "").isEmpty) {
      warnings.add("Prénom non détecté");
    }
    if ((fields["prenom_pere"] ?? "").isEmpty) {
      warnings.add("Prénom du père non détecté");
    }
    if ((fields["nom_famille"] ?? "").isEmpty) {
      warnings.add("Nom de famille non détecté");
    }
    if ((fields["date_naissance"] ?? "").isEmpty) {
      warnings.add("Date de naissance non détectée");
    }
    if ((fields["lieu_naissance"] ?? "").isEmpty) {
      warnings.add("Lieu de naissance non détecté");
    }
    return warnings;
  }

  static String detectDocumentType(String rawText) {
    final text = _normalize(rawText);
    if (text.contains("passport")) return "Passeport";
    if (text.contains("carte") || text.contains("identite")) {
      return "Carte d'identité";
    }
    if (text.contains("permis")) return "Permis";
    return "Document";
  }
}
