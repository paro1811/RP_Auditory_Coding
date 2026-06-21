Input_dir = 'D:\InetPub\wwwroot\Figure_Data\Carney';
Output_dir = 'D:\InetPub\wwwroot\Figure_Data\Carney\Converted';

eval(['cd ', Input_dir]);
eval(['!dir  *.10  /B >  ', Output_dir,'\File_list']);

eval(['cd ', Output_dir]);

counter=0;
fid_list = fopen('File_list','r');

 while 1
    file_name = fgetl(fid_list);
    if ~isstr(file_name), break, end




	Outputfilename=strrep(strrep(file_name, 'revfunc.c8', '8'), '.', '-');

	eval(['cd ', Input_dir]); 
   
   [DAT_fid,E_message2] = fopen(file_name,'r');           

	DATA_SIZE = [2,inf];

	Data_file = fscanf(DAT_fid,'%f',DATA_SIZE);
   
   

	fclose(DAT_fid);
   
   counter=counter+1;
   
   
   
   size_data = size(Data_file);

F_NAME = [ Outputfilename  '.ascii' ];

FID = fopen(F_NAME,'w');

fprintf(FID,'%s    %s \n\n',x_label,y_label);

for i = 1:size_data(1)
	fprintf(FID,'%f    %f \n',Data_file(1,i), Data_thief(2,i));
end

fprintf(FID,'\n\n%s   ',data_info);  

fclose(FID);

clear size_data F_NAME FID i

   
   
   
   

x_label= 'Time';
y_label= 'Magnitude';
info= 'Reverse Correlation Function';

eval(['save ' Outputfilename ' Data_file x_label y_label info -ascii']);
end

Number_of_files_processed=counter