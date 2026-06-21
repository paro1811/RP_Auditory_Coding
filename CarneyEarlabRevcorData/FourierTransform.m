clear

npts=512;
m=zeros(400,2);
m=[X_thief; Y_thief(2,1:400)];
m=m';

DeltaFreq=1000/(npts*(m(2,1)-m(1,1)));
F=DeltaFreq*[0:npts/2];
S=fft(m(1:400,2),npts);
smoothF=conv(abs(S(1:1+npts/2)),hanning(5));
[Y,I]=max(smoothF);
CF=DeltaFreq*(I-3);




loglog(F(1:1+npts/2),abs(S(1:1+npts/2)));
grid;
xlabel('Frequency (Hz)');
ylabel('Magnitude');
title(TitleString);
