% --- DIŞARIDAN RESİM SEÇİP ŞABLONA EKLEME ARACI ---
clc; clear; close all;

% 1. Veritabanını Yükle
if exist('alphaNumericTemplates.mat', 'file')
    load('alphaNumericTemplates.mat');
    disp(['Mevcut veritabanı yüklendi. Toplam şablon: ' num2str(length(templates))]);
else
    error('alphaNumericTemplates.mat bulunamadı! Önce veritabanını oluşturmalısın.');
end

% 2. Bilgisayardan Resim Seçtirme Penceresi
[dosya_adi, dosya_yolu] = uigetfile({'*.jpg;*.png;*.bmp', 'Resim Dosyaları'}, 'Şablon Yapılacak Resmi Seçin');

if isequal(dosya_adi, 0)
    disp('Dosya seçilmedi, işlem iptal edildi.');
    return;
end

% Resmi Oku
ham_resim = imread(fullfile(dosya_yolu, dosya_adi));

% 3. Resmi Şablon Formatına Dönüştürme
% Eğer resim renkliyse griye çevir
if size(ham_resim, 3) == 3
    gri_resim = rgb2gray(ham_resim);
else
    gri_resim = ham_resim;
end

% Binary (Siyah-Beyaz) yap
binary_resim = imbinarize(gri_resim);

% --- ÖNEMLİ KONTROL: Harf Beyaz, Zemin Siyah Olmalı ---
% Köşelere bakarak zemin rengini anla. Eğer zemin beyazsa resmi ters çevir.
if binary_resim(1,1) == 1 
    binary_resim = ~binary_resim; % Tersini al (Invert)
    disp('Resim ters çevrildi (Zemin siyah yapıldı).');
end

% FAZLALIKLARI KIRP (Auto-Crop) - Harfi tam ortalamak için
[y, x] = find(binary_resim);
if ~isempty(y)
    binary_resim = binary_resim(min(y):max(y), min(x):max(x));
end

% Şablon Boyutuna Zorla (42x24 piksel)
yeni_sablon = imresize(binary_resim, [42 24]);

% 4. Kullanıcıya Hangi Harf Olduğunu Sor
cevap = inputdlg({'Bu resim hangi harf/rakam?:'}, 'Etiket Gir', [1 35]);

if isempty(cevap)
    disp('Harf girilmedi, işlem iptal.');
    return;
end

yeni_etiket = upper(cevap{1}); % Büyük harfe çevir
if length(yeni_etiket) ~= 1
    disp('HATA: Lütfen tek bir harf veya rakam girin!');
    return;
end

% 5. Son Kontrol Penceresi
figure;
subplot(1,2,1); imshow(ham_resim); title('Orijinal Resim');
subplot(1,2,2); imshow(yeni_sablon); title(['Eklenecek Şablon: ' yeni_etiket]);
sgtitle('Onaylıyor musunuz?');

onay = questdlg(['Bu resmi "' yeni_etiket '" olarak kaydetmek istiyor musun?'], ...
	'Kaydetme Onayı', 'Evet', 'Hayır', 'Evet');

if strcmp(onay, 'Evet')
    % LİSTEYE EKLE
    templates{end+1} = yeni_sablon;
    template_labels = [template_labels yeni_etiket];
    
    % KAYDET
    save('alphaNumericTemplates.mat', 'templates', 'template_labels');
    msgbox(['Başarıyla Eklendi! Yeni şablon sayısı: ' num2str(length(templates))]);
else
    disp('Kayıt iptal edildi.');
end