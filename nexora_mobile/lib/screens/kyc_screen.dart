import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/theme/app_theme.dart';
import '../services/kyc_service.dart';

class KycScreen extends StatefulWidget {
  const KycScreen({super.key});

  @override
  State<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends State<KycScreen> {
  File? idImage;
  File? selfieImage;
  bool isLoading = false;
  bool loadingKyc = true;
  Map<String, dynamic>? kycData;

  String get status => kycData?["status"]?.toString() ?? "NOT_SUBMITTED";
  bool get isApproved => status == "APPROVED";

  Future<void> loadKyc() async {
    try {
      final response = await KycService.getMyKyc();
      if (!mounted) return;
      setState(() {
        if (response.data is List && response.data.isNotEmpty) {
          kycData = Map<String, dynamic>.from(response.data[0]);
        }
        loadingKyc = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loadingKyc = false;
      });
    }
  }

  Future<void> pickIdImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 1600,
    );
    if (picked != null) {
      setState(() {
        idImage = File(picked.path);
      });
    }
  }

  Future<void> pickSelfie() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 75,
      maxWidth: 1600,
    );
    if (picked != null) {
      setState(() {
        selfieImage = File(picked.path);
      });
    }
  }

  Future<void> submitKyc() async {
    if (isApproved) {
      _showMessage("Votre KYC est deja approuve");
      return;
    }

    if (idImage == null || selfieImage == null) {
      _showMessage("Selectionnez la piece et le selfie");
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final formData = FormData.fromMap({
        "id_document": await MultipartFile.fromFile(
          idImage!.path,
          filename: "id_document.jpg",
        ),
        "selfie": await MultipartFile.fromFile(
          selfieImage!.path,
          filename: "selfie.jpg",
        ),
      });

      await KycService.submitKyc(formData);
      await loadKyc();

      if (!mounted) return;
      _showMessage("KYC envoye");
    } catch (_) {
      if (!mounted) return;
      _showMessage("Echec de l'envoi KYC");
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void initState() {
    super.initState();
    loadKyc();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("KYC Verification")),
      body: loadingKyc
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _statusCard(),
                  const SizedBox(height: 20),
                  _imagePickerCard(
                    title: "Document d'identite",
                    image: idImage,
                    icon: Icons.badge_outlined,
                    onPressed: isApproved ? null : pickIdImage,
                  ),
                  const SizedBox(height: 16),
                  _imagePickerCard(
                    title: "Selfie",
                    image: selfieImage,
                    icon: Icons.photo_camera_outlined,
                    onPressed: isApproved ? null : pickSelfie,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: isLoading || isApproved ? null : submitKyc,
                      child: isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("Submit KYC"),
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (kycData != null) _ocrData(),
                ],
              ),
            ),
    );
  }

  Widget _statusCard() {
    final color = switch (status) {
      "APPROVED" => Colors.green,
      "REJECTED" => Colors.red,
      "PENDING" => Colors.orange,
      _ => Colors.blue,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Statut KYC",
            style: TextStyle(
              color: AppColors.text,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            status,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
          if ((kycData?["rejection_reason"]?.toString() ?? "").isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              "Raison: ${kycData!["rejection_reason"]}",
              style: const TextStyle(color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _imagePickerCard({
    required String title,
    required File? image,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.surfaceSoft),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: image == null
                  ? Container(
                      color: AppColors.panel,
                      child: Icon(icon, color: AppColors.muted, size: 48),
                    )
                  : Image.file(image, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon),
              label: Text(image == null ? "Ajouter" : "Changer"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ocrData() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "OCR Information",
          style: TextStyle(
            color: AppColors.text,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _infoTile("NNI", kycData!["nni"]),
        _infoTile("Prenom", kycData!["prenom"]),
        _infoTile("Prenom Pere", kycData!["prenom_pere"]),
        _infoTile("Nom Famille", kycData!["nom_famille"]),
        _infoTile("Sexe", kycData!["sexe"]),
        _infoTile("Date Naissance", kycData!["date_naissance"]),
        _infoTile("Lieu Naissance", kycData!["lieu_naissance"]),
      ],
    );
  }

  Widget _infoTile(String title, dynamic value) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.surfaceSoft),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value?.toString() ?? "",
            style: const TextStyle(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
