# Function to save me from uploading all files manually.
#  Usage: Concatenate all files into one file and separate them by
#   a start line with # XxX FILE STARTS ?<filename to write>?
#   and a end line with # XxX FILE ENDS
# Shell script for concatenation: 
# for file in * ; do echo "# XxX FILE STARTS ?"$file"?" >>upload.all ; cat $file >>upload.all; echo  >>upload.all; echo "# XxX FILE ENDS" >>upload.all; done
# In Berry: 
# load("util.be")
# filesplit("upload.all")
import string
import path

def filesplit(filename)
    var file=open(filename,"r") # only text files are allowed
    var linebuffer=""
    var filenameout
    var filepointer=-1
    while file.tell() != filepointer # still not the end
        filepointer=file.tell()
        linebuffer=file.readline()
        #print("line read, pointer:", filepointer)
        while string.find(linebuffer,"# XxX FILE STARTS",0)<0 #search for start
            if file.tell() == filepointer
                #print ("end reached without start")
                return filepointer
            end
            filepointer=file.tell()
            linebuffer=file.readline() 
            #print("line read, pointer:", filepointer)
        end
        # Start found
        filenameout=string.split(linebuffer,"?")[1]
        var fileout=open(filenameout,"w")
        linebuffer=file.readline() # next line
        #print("line read, pointer:", filepointer)
        while string.find(linebuffer,"# XxX FILE ENDS",0)<0 # search for end
            if file.tell() == filepointer
                #print ("end reached without end")
                return filepointer
            end
            filepointer=file.tell()
            fileout.write(linebuffer+"\n")
            linebuffer=file.readline() # next line
            #print("line read, pointer:", filepointer)
        end
        fileout.close()
    end
    file.close()
end

def moveiconstofolder()
    for file:path.listdir("/")
        if string.endswith(file, "miff")
          path.rename("/"+file,"/icons/"+file)
        end
      end
    for file:path.listdir("/")
        if string.endswith(file, "pam")
            path.rename("/"+file,"/icons/"+file)
        end
    end
end

            






    


