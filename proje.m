%Preprocessing  Start

try
input_image=imread('ornek_plaka2.jpg');
disp('Goruntu Basariyla Eklendi');

catch
    disp('Goruntu Eklenirken Bir Hata Olustu...');
    return ;
end
%RGB den gri tonlamaya cevirme 
% I = 0.299*R + 0.587*G + 0.114*B  formuluyle



R=input_image(:,:,1);  %goruntunun birinci kanati kirmiziyi temsil ediyor.
G=input_image(:,:,2);
B=input_image(:,:,3);
GrayImage=0.299*double(R)+ 0.587*double(G)+ 0.114*double(B);
GrayImage=uint8(GrayImage);

disp('Goruntu Gri Tonlamaya Donusturuldu.');

[row,col,~]=size(GrayImage);
ReducedImage=imresize(GrayImage,[round(row/2),round(col/2)]);
disp('Cozunurluk Azaltildi Hesaplama Suresi Azaldi.')

GurultusuzGoruntu=imbilatfilt(ReducedImage);
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

%Preprocessing Finish

%Localization Start
BinaryImage=imbinarize(ProcessedImage);
disp('Ikili Goruntuye Donusturuldu');

EdgeImage=edge(BinaryImage,'sobel');
disp('Sobel Filtresi Kullanilarak Kenarlari Tespit Edildi');
se_plate = strel('rectangle', [10, 20]); % [boy, en] -> Genişlemesine yayar tekrar bak
DilatedImage = imdilate(EdgeImage, se_plate);

FilledImage=imfill(DilatedImage,'holes');

disp('Bosluklar Dolduruldu ve Kenarlar Birlestirildi.');


figure;
subplot(3,1,1);
imshow(BinaryImage);
title('a) Ikili Goruntu');

subplot(3,1,2);
imshow(EdgeImage);
title('b) Sobel Filtresi Uygulanmis Hali(Kenar Tespiti)');

subplot(3,1,3);
imshow(FilledImage);
title('c) Birlestirilmis Aday Bolge');

%Localization finish

[L,num]=bwlabel(FilledImage);  %goruntuleri etiketledik
%num : toplam bulunan nesne sayisi
stats=regionprops(L,'BoundingBox','Area');

maxArea=0;
plaka=[];
for i=1:num
    box=stats(i).BoundingBox;
    area=stats(i).Area;
    width=box(3);
    height=box(4);

    WH_Ratio=width/height;
    fprintf('alan:%d , oran:%.2f',area,WH_Ratio);
    if area>maxArea &&WH_Ratio>1.5
        maxArea=area;
        plaka=box; %bu koordinatlar x,y,width,height  gercek plaka
                   %bolgesini temsil ediyor
    end
    
end

if isempty(plaka) 
      disp('Plaka Tespit Edilemedi.');
      return;
end

PlateImage=imcrop(ReducedImage,plaka);
disp('Plaka Bolgesi Basariyla Kesildi.');


PlateBinary=imbinarize(PlateImage);
if mean(PlateBinary(:))>0.5  % beyazlar siyahlardan fazla ise yani  beyaz arkaplana
                            % siyah karakterler islendiyse bwlabel beyazlari
                            %  sayar o yuzden goruntunun tersini aliriz.
    PlateBinary=~PlateBinary;                        

end
PlateBinary=bwareaopen(PlateBinary,100);   

[L_char,num_char]=bwlabel(PlateBinary); % Kesilmis plakadaki karakter sayisini buluruz.

char_stats=regionprops(L_char,'BoundingBox','Area','Image'); %image sadece 
                                             % bir kararkterin gorselini alir.

figure;
subplot(2,1,1);
imshow(PlateImage);
title('Kesilen Plaka');

subplot(2,1,2);
imshow(PlateBinary);
title('Segmentasyon Icin Hazir Binary Plaka');



















