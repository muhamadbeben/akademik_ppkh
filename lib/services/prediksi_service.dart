import 'dart:convert';
import 'package:http/http.dart' as http;

class PrediksiApiService {
  // Masukkan URL Forwarding dari Ngrok di sini, tambahkan endpoint /predict
  static const String apiUrl = "https://excuse-mammogram-marbles.ngrok-free.dev/predict"; 

  static Future<int> getPrediksiKelulusan({
    required double hafalanKitab,
    required double kehadiran,
    required double nilaiAkademik,
    required double nilaiPerilaku,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "hafalan_kitab": hafalanKitab,
          "kehadiran": kehadiran,
          "nilai_akademik": nilaiAkademik,
          "nilai_perilaku": nilaiPerilaku,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
           return data['hasil_prediksi'];
        } else {
           throw Exception(data['message']);
        }
      } else {
        throw Exception("Gagal terhubung ke API backend.");
      }
    } catch (e) {
      throw Exception("Error jaringan: $e");
    }
  }
}