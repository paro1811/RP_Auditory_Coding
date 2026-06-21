Input_dir = 'D:\InetPub\wwwroot\Figure_Data\Langner';

eval(['cd ', Input_dir]);
eval(['!dir *.ascii /B >  ', Input_dir,'\File_list']);

counter =0;
fid_list = fopen('File_list','r');

 while 1
    file_name = fgetl(fid_list);
    if ~isstr(file_name), break, end
    
    Outputfilename=strrep(file_name, '.ascii', '.txt');
    
    copyfile(file_name, Outputfilename, 'writable');  
		
   counter=counter+1;
   
end

Number_of_files_processed=counter