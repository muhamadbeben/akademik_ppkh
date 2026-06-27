from flask import Flask, request, jsonify
import pickle
import numpy as np

app = Flask(__name__)

# 1. Muat Model Random Forest DAN Scaler-nya
with open('final_model_rf .pkl', 'rb') as f_model:
    model = pickle.load(f_model)

with open('final_scaler_rf .pkl', 'rb') as f_scaler:
    scaler = pickle.load(f_scaler)

@app.route('/predict', methods=['POST'])
def predict():
    try:
        data = request.json
        
        # Susun data asli dari Flutter
        input_raw = np.array([[
            data['hafalan_kitab'], 
            data['kehadiran'], 
            data['nilai_akademik'], 
            data['nilai_perilaku']
        ]])
        
        # 2. WAJIB: Lakukan scaling pada input sebelum diprediksi!
        input_scaled = scaler.transform(input_raw)
        
        # 3. Masukkan data yang sudah di-scale ke dalam model
        prediction = model.predict(input_scaled)
        
        return jsonify({
            'status': 'success',
            'hasil_prediksi': int(prediction[0])
        })
    except Exception as e:
        return jsonify({'status': 'error', 'message': str(e)}), 400

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)