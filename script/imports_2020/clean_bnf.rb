bnf_dir = "/home/axel/bnf_ftp"
Dir.chdir(bnf_dir)
Dir.glob('*').each_with_index do |dir_path, idx|
  puts dir_path
end