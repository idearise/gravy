# load documents
require 'logger'
require 'find'
require 'lib/gravy'

logger = Logger.new('log/load.log', 3, 1024000)
logger.level = Logger::DEBUG
Gravy.logger = logger

#Gravy::Node.new.delete_database("test")
db = Gravy::Node.new.create_database("test")

file_source = "/home/share/projects/couchdb"

Find.find(file_source) do |path|  
  loadable = case  
    when File.file?(path) then true
    when File.directory?(path) then false
    else false
  end  
  
  if loadable
    p path

    content_type = Gravy::Utensils.content_type_for(path)
    content_length = File.size(path)

    doc = db.create_document( { :name => path,
                                :content_type => content_type,
                                :size => content_length,
                                :created_on => File.ctime(path),
                                :updated_on => File.mtime(path),
                                :accessed_on => File.atime(path) } )
    
    if File.readable?(path)
      contents = ""
      File.open(path, "r").each { |line| contents << line }
    end

    sa = doc.create_standalone_attachment(File.basename(path), content_type, content_length, contents)
  end
end
