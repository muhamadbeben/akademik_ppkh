bat_content = """@echo off
setlocal enabledelayedexpansion

:: Mengatur judul jendela command prompt
title Dart File Merger & Splitter

echo ===================================================
echo       DART FILE MERGER TO 13 TEXT FILES
echo ===================================================
echo.

:: Menghapus file hasil gabungan lama jika ada agar tidak menumpuk
echo [1/3] Membersihkan file lama (gabung_*.txt) jika ada...
for /l %%i in (1,1,13) do (
    if exist "gabung_%%i.txt" del "gabung_%%i.txt"
)
echo Bersih!
echo.

:: Inisialisasi counter file gabung (1 sampai 13) dan total file
set "counter=1"
set "total_files=0"

echo [2/3] Memproses dan mendistribusikan file .dart...
echo ---------------------------------------------------

:: Melakukan perulangan secara rekursif mencari semua file .dart di folder saat ini dan subfolder
for /r %%f in (*.dart) do (
    set /a "total_files+=1"
    echo Menambahkan: %%~nxf -^> gabung_!counter!.txt
    
    :: Menulis header batas penanda file di dalam text file
    echo ============================================================ >> "gabung_!counter!.txt"
    echo PATH FILE: %%~f >> "gabung_!counter!.txt"
    echo NAMA FILE: %%~nxf >> "gabung_!counter!.txt"
    echo ============================================================ >> "gabung_!counter!.txt"
    echo. >> "gabung_!counter!.txt"
    
    :: Memasukkan seluruh isi text dari file .dart
    type "%%f" >> "gabung_!counter!.txt"
    
    :: Memberikan space baris kosong di bawahnya sebagai pemisah antar file
    echo. >> "gabung_!counter!.txt"
    echo. >> "gabung_!counter!.txt"
    echo. >> "gabung_!counter!.txt"

    :: Logika Round-Robin untuk berpindah ke file gabung berikutnya (1-13)
    set /a "counter+=1"
    if !counter! gtr 13 set "counter=1"
)

echo ---------------------------------------------------
echo [3/3] Proses Selesai Semuanya!
echo Total file .dart yang berhasil diproses: !total_files! file.
echo Hasil akhir tersimpan dalam bentuk file gabung_1.txt sampai gabung_13.txt.
echo.
pause
"""

with open("gabung_dart.bat", "w", encoding="utf-8") as f:
    f.write(bat_content)

print("File gabung_dart.bat successfully generated.")