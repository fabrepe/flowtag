if ENV['PATH'][config('bindir')] == nil
  puts "Creating symlinks to installed executable scripts into /usr/local/bin"
  ['flowtag', 'listflows', 'pcap2flowdb', 'printflow'].each do |bin|
    File.symlink(config('bindir')+"/"+bin, "/usr/local/bin/"+bin)
  end
end

