Input_dir = 'D:\InetPub\wwwroot\Figure_Data\Carney';
Output_dir = 'D:\InetPub\wwwroot\Figure_Data\Carney\Converted';

eval(['cd ', Input_dir]);
eval(['!dir  *.10 *.20 *.30 *.40 *.50 *.60 *.70 *.80 *.55 *.65 *.75 /B >  ', Output_dir,'\File_list']);

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
   for i=1:400
      X_thief(1,i)=Data_file(1,i);
      Y_thief(2,i)=Data_file(2,i);
   end
   counter=counter+1;
   
x_label= 'Time';
y_label= 'Magnitude';
data_info= 'Reverse Correlation Function';
 
   
eval(['save ' Outputfilename ' X_thief Y_thief x_label y_label data_info ']);   
   
end

Number_of_files_processed=counter