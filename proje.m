% --- Görüntüyü Yükleme ve Ön İşleme Başlanıyor ---
try
    
    input_image=imread('ornek_plaka.jpg'); 
    disp('Goruntu Basariyla Eklendi');
catch
    disp('Goruntu Eklenirken Bir Hata Olustu...');
    return ;
end
% RGB'den Gri Tonlamaya Çevirme 
R=input_image(:,:,1); 
G=input_image(:,:,2);
B=input_image(:,:,3);
GrayImage=0.299*double(R)+ 0.587*double(G)+ 0.114*double(B);
GrayImage=uint8(GrayImage);
disp('Goruntu Gri Tonlamaya Donusturuldu.');
[row,col,~]=size(GrayImage);
GurultusuzGoruntu=imbilatfilt(GrayImage);
disp('Gurultu(Noise) Giderildi');
figure;
subplot(1,3,1);
imshow(input_image);
title('a) Orijinal Goruntu');
subplot(1,3,2);
imshow(GrayImage);
title('b) Gri Tonlamali Goruntu');
subplot(1,3,3);
imshow(GurultusuzGoruntu);
title('c) Gurultu Giderilmis Goruntu');
ProcessedImage=GurultusuzGoruntu;
disp('Goruntu Onisleme Tamamlandi...')
% --- Plaka Lokalizasyonu Başlangıcı ---
EdgeImage = edge(ProcessedImage,'sobel','vertical'); %sobel parlakliga dayaniklii , vertical sadece dikey cizgiler
kernel_listesi = [4, 10; 8, 40; 12,70; 15, 30;]; % olusabilecek plaka buyuklukleri plakanin yakinlik uzakliga bagli.
globalBestPlate = []; globalBestImage = []; globalMaxArea = 0;          
for k = 1:size(kernel_listesi, 1) %satir sayisina gore 
    boy = kernel_listesi(k, 1); % [4 10], 4 boy, 10 en 
    en  = kernel_listesi(k, 2);
    fprintf('--- Deneme %d: Kernel [%d, %d] ile analiz ediliyor ---\n', k, boy, en);
    se_plate = strel('rectangle', [boy, en]);
    tempFilled = imclose(EdgeImage, se_plate);
    tempFilled = imfill(tempFilled, 'holes');
    [L, num] = bwlabel(tempFilled);
    stats = regionprops(L, 'BoundingBox', 'Area');
    
    for i = 1:num
        box = stats(i).BoundingBox;
        area = stats(i).Area;
        width = box(3);
        height = box(4);
        WH_Ratio = width / height;
        extend = area / (width * height); % doluluk orani dikdorgen bolgeyi cikarmak icin yardimci.
        
        karePlakaSarti = (WH_Ratio > 1.0 && WH_Ratio < 2.3);
        uzunPlakaSarti = (WH_Ratio >= 3 && WH_Ratio < 6.0);
        alanSarti = (area > 1700 && area < 70000);
        
        if (karePlakaSarti || uzunPlakaSarti) && alanSarti && extend > 0.4
            if area > globalMaxArea
                globalMaxArea = area;        
                globalBestPlate = box;       
                globalBestImage = tempFilled;
            end
        end
    end
end
if isempty(globalBestPlate)
    disp('HATA: Hiçbir boyutla Plaka Tespit Edilemedi.');
    return;
else
    plaka = globalBestPlate;         
    FinalFilledImage = globalBestImage; 
    disp(['SONUÇ: En uygun plaka ' num2str(globalMaxArea) ' alanı ile seçildi.']);
end
disp('Kenarlar Birlestirildi.');
% 2. FIGURE ÇİZDİRME
figure;
subplot(3,1,1); imshow(FinalFilledImage); title('a) Ikili Goruntu'); % BinaryImage yerine FinalFilledImage kullanıldı
subplot(3,1,2); imshow(EdgeImage); title('b) Kenar Tespiti');
subplot(3,1,3); imshow(FinalFilledImage); title('c) En Iyi Aday Bolge');
% --- CROP VE SEGMENTASYON ---
PlateImage = imcrop(GrayImage, plaka);
disp('Plaka Bolgesi Basariyla Kesildi.');
[h_img, w_img] = size(PlateImage);
PlateBinary = imbinarize(PlateImage,'adaptive','ForegroundPolarity','dark','Sensitivity',0.4); % sonrasinda arkaplan beyaz harler siyah oldu
                               % matlab beyazlari nesne oalrak kabul eder
                               % adaptive ->golgeleri umursamaz.    
                                                          
                                                                    
PlateBinary = ~PlateBinary;   % o yuzden tersini aldik harfler beyaz artik.
if mean(PlateBinary(:)) > 0.5  % bu demek beyaz agirlikli plaka yani arka plan beyaz olmus demek
    PlateBinary = imcomplement(PlateBinary);   %Son durumda resim beyaz yazilar siyahsa otomatik duzelt                      
end
PlateBinary = bwareaopen(PlateBinary, 80);   
% 3. FIGURE
figure;
subplot(2,1,1); imshow(PlateImage); title('Kesilen Plaka');
subplot(2,1,2); imshow(PlateBinary); title('Segmentasyon Icin Hazir Binary Plaka');
disp('Karakterler Ayristiriliyor');
% - TEMİZLİK 
plaka_en_boy_orani = w_img / h_img;
min_harf_boy_orani = 0.24; 
% - 1. ADIM: KENAR VE TR TEMIZLIGI -
% Burada alt ust bosluklar ve gereksiz kenarlar sifirlanir
if plaka_en_boy_orani < 2.1
    % KARE (ÇİFT SATIR) PLAKA MODU 
    disp('Mod: Kare Plaka - Temizlik yapiliyor.');
    sil_payi_y = 2; 
    PlateBinary(1:sil_payi_y, :) = 0; 
    PlateBinary(end-sil_payi_y:end, :) = 0;
    
    % Sol Kenar Temizligi (TR Amblemi)
    TR_temizlik_orani = 0.04; 
    sil_payi_x_dinamik = round(w_img * TR_temizlik_orani);
    sil_payi_x_dinamik = max(3, sil_payi_x_dinamik); 
    PlateBinary(:, 1:sil_payi_x_dinamik) = 0;  
    
    PlateBinary(:, end-3:end) = 0; 
else
    % TEK SATIR (UZUN) PLAKA MODU
    disp('Mod: Standart Plaka.');
    PlateBinary(1:5, :) = 0; PlateBinary(end-5:end, :) = 0;
    
    % Sol Kenar Temizliği (TR Amblemi)
    TR_temizlik_orani = 0.04; 
    sil_payi_x_dinamik = round(w_img * TR_temizlik_orani);
    sil_payi_x_dinamik = max(3, sil_payi_x_dinamik); 
    PlateBinary(:, 1:sil_payi_x_dinamik) = 0;  
end
% --- 2. ADIM: KAPSAMLI GÜRÜLTÜ SİLME VE MORFOLOJİK İŞLEMLER 

PlateBinary = bwareaopen(PlateBinary, 60); 
se_disk = strel('disk', 1);
PlateBinary = imopen(PlateBinary, se_disk);  % Karakterler arasini cok yakinsa ayirir.
PlateBinary = bwareaopen(PlateBinary, 90);   % Bu eşik 90'da kaldı.

[L_char, num_char] = bwlabel(PlateBinary); %plaka uzerindeki nesneleri numaralandirir ve sayisini bulur.
char_stats = regionprops(L_char,'BoundingBox','Area','Image','Centroid'); %karakterlerin tek tek geometrik ozelliklerini cikarir.
                                                                
%centroid :  karakterlerin fotograftaki ort x ve y koordinatlari. Kutle
%merkezi gibi dusun.
    
                                                             
% --- 4. ADIM: ORTALAMA ALAN KONTROLU (Gürültü Elenir) ---
tum_alanlar = [char_stats.Area];
if isempty(tum_alanlar)
    disp('HATA: Segmentasyon sonrası hiç karakter adayı bulunamadı.');
    return;
end
ortalama_alan = mean(tum_alanlar); % Bulunan bolgelerin alanlari ortalamasi
gecerli_indexler = find([char_stats.Area] > (ortalama_alan * 0.1)); % . Area vektor seklinde tum alanlari tutar.
char_stats = char_stats(gecerli_indexler); 

% Gürültü son :

plaka_toplam_alani = w_img * h_img;
min_karakter_alan_orani = 0.003; % Toplam plaka alanının en az %0.3'ü olmalı (TR'nin en küçük harfi dahil)

%Kenar Temizligi sag sol alt ust 
sol_marjin_x = w_img * 0.10; sag_marjin_x = w_img * 0.97;
ust_marjin_y = h_img * 0.03; alt_marjin_y = h_img * 0.98;

final_gecerli_indexler = [];
for k = 1:length(char_stats)
    box = char_stats(k).BoundingBox;
    x_baslangic = box(1); x_bitis = box(1) + box(3); % 1 baslangic 3 genislik x le alakali
    y_baslangic = box(2); y_bitis = box(2) + box(4);% 4 yukseklik y ile alakali
    
    % A1: Alan Kontrolü (Toplam Alana Göre Mutlak Alan Eşiği)
    alan_uygun = char_stats(k).Area > (plaka_toplam_alani * min_karakter_alan_orani);
    
    % A2: Konum Kontrolü (Kenar marjinleri gevşetildi)
    konum_uygun = (x_baslangic >= sol_marjin_x) && (x_bitis <= sag_marjin_x) && (y_baslangic >= ust_marjin_y) && (y_bitis <= alt_marjin_y);
    
    if konum_uygun && alan_uygun
        final_gecerli_indexler = [final_gecerli_indexler k];
    end
end
char_stats = char_stats(final_gecerli_indexler);
disp(['Nihai Konum ve Alan elemesinden sonra ', num2str(length(char_stats)), ' karakter adayı kaldı.']);


% Karakterlerin Siralanmasi.
tum_kutular = vertcat(char_stats.BoundingBox);
if ~isempty(tum_kutular)
    y_koordinatlari = tum_kutular(:,2); %2.sutunda y
    x_koordinatlari = tum_kutular(:,1); % 1.sutunda x   3 ve 4 te w, h tutlur sirasiyla
    
    if plaka_en_boy_orani < 2.1 % kare icin cift satirli plakar yani
        % Satır tespiti
        ortalama_y = mean(y_koordinatlari);
        satir_no = (y_koordinatlari > ortalama_y) + 1; %usttekiler 1. alttakiler 2.satir olur kare plakada
                        % Ortalamadan buyukse asagi satirda demek.
        sirala_matrisi = [satir_no, x_koordinatlari];
    else
        sirala_matrisi = x_koordinatlari;
    end
    
    [~, sira_indeksi] = sortrows(sirala_matrisi);
    char_stats = char_stats(sira_indeksi);
end


% --- GÖRSELLEŞTİRME: SEGMENTASYON SONUCU VE KUTULAMA ---
figure;
imshow(PlateImage); 
title('Kesilecek Karakterler (Yesil Cerceve ile)');
hold on; 
if ~isempty(tum_kutular)
    for i = 1:size(tum_kutular, 1)
        kutu = tum_kutular(i,:);
        rectangle('Position', kutu, 'EdgeColor', 'g', 'LineWidth', 2); % cizgi kalinligi 2  position kutunu konum bilgileri
    end
end
hold off;
% --- TANIMA DÖNGÜSÜ ---
disp('Karakterler Okunuyor...');
% --- VERİTABANI YÜKLEME ---
template_labels = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'; 
tanima_aktif = false;
if exist('alphaNumericTemplates.mat', 'file')
    try
        load('alphaNumericTemplates.mat'); 
        if exist('templates','var') && ~isempty(templates)
            tanima_aktif = true;
            disp('Veritabanı Basariyla Yuklendi.');
        else
            warning('Mat dosyasında "templates" degiskeni bulunamadi veya boş!');
        end
    catch ME
        warning(['Veritabanı yuklenirken hata olustu: ', ME.message]);
        warning('Tanima atlanacak.');
    end
else
    warning('alphaNumericTemplates.mat dosyasi bulunamadi! Tanima atlanacak.');
end
% --- YUKLEME BITISI ---
gecerli_karakterler={};
sayac=0;
sonuc_plaka_yazisi = [];
figure; 
sgtitle('Bulunan ve Tanınan Karakterler'); 
for i=1:length(char_stats)
    box=char_stats(i).BoundingBox;
    img=char_stats(i).Image;
    h=box(4); 
    w=box(3); 
    
    % Yükseklik ve Oran Koşulları (Tanıma Dögüsünün kendi filtreleri)
    yukseklik_kosulu = (h > (h_img * min_harf_boy_orani));
    enBoy = h/w;
    oran_kosulu = (enBoy > 0.8 && enBoy < 6.0); 
    
    if yukseklik_kosulu && oran_kosulu
        sayac = sayac + 1;
        [satir, sutun] = find(img); 
        
        if ~isempty(satir)
            img = img(min(satir):max(satir), min(sutun):max(sutun));
        end
        % BOYUT ESİTLEME
        standart_img = imresize(img, [42 24]); 
        gecerli_karakterler{sayac} = standart_img;
        
        bulunan_karakter = '?';
        maks_deger = 0; 
        indeks = 0; 
        % --- TANIMA İŞLEMİ (ŞABLON EŞLEŞTİRME) ---
        if tanima_aktif
            for j=1:length(templates)
                % Korelasyon (Hem normal hem tersini kontrol et)
                c1 = corr2(templates{j}, standart_img);  % Benzerlik orani
                c2 = corr2(templates{j}, ~standart_img);
                
                benzerlik = max(c1, c2); 
                
                if benzerlik > maks_deger
                    maks_deger = benzerlik;
                    indeks = j;
                end
            end
            
            % EŞİK DEĞERİ (Threshold)
            if maks_deger > 0.40 && indeks >= 1 && indeks <= length(template_labels)
                bulunan_karakter = template_labels(indeks); 
                fprintf('Harf: %s | Benzerlik: %% %.2f \n', bulunan_karakter, maks_deger*100);
            else
                bulunan_karakter = '?';
                fprintf('Okunamadi (Benzerlik çok düşük: %% %.2f)\n', maks_deger*100);
            end
        end
        
        % Sonuç metnine ekle
        if bulunan_karakter ~= '?'
            sonuc_plaka_yazisi = [sonuc_plaka_yazisi bulunan_karakter];
        end
        
         
        % Görselleştirme
        subplot(1, 10, sayac); 
        imshow(standart_img);
        title([bulunan_karakter, ' %', num2str(round(maks_deger*100))]);
    end
end

disp('------------------------------------------------');
disp(['OKUNAN PLAKA: ' sonuc_plaka_yazisi]);
disp('------------------------------------------------');

% --- SONUÇ PENCERESİ  ---
hFig = figure('Name', 'Plaka Tanıma Sonucu', ... % Ayri  figur olusturduk 
              'NumberTitle', 'off', ...
              'MenuBar', 'none', ...
              'ToolBar', 'none', ...
              'Position', [500, 500, 400, 150], ... % Pencerenin ekrandaki yeri ve boyutu
              'Color', [0.9 0.9 0.45]); % Arka plan rengi 

% 2.  Label
uicontrol('Parent', hFig, ...
          'Style', 'text', ...
          'Position', [50, 100, 300, 20], ...
          'String', 'TESPİT EDİLEN PLAKA', ...
          'FontSize', 12, ...
          'FontWeight', 'bold', ...
          'BackgroundColor', [0.19 0.49 0.34]);

% 3. Sonuç Kutusu (Edit Box)
uicontrol('Parent', hFig, ...
          'Style', 'edit', ... % 'edit'  yazı yazılabilir kutu demek.
          'Position', [50, 50, 300, 40], ...
          'String', sonuc_plaka_yazisi, ... % Ekrana yazdirilacak degisken
          'FontSize', 18, ...
          'FontWeight', 'bold', ...
          'ForegroundColor', 'white', ... 
          'BackgroundColor', 'black');
