require 'fileutils'
require 'colored'
require 'open3'

$debug = false

####################################################################################################

$currentdir = File.expand_path(File.dirname(__FILE__))
$tmp        = ENV["tmp"] || "C:\\Temp" # Укажем значение по умолчанию, если ENV["tmp"] не задано
$progs      = ENV["progs"] || "C:\\Program Files (x86)"
$vs         = ENV["vs"] || "C:\\Program Files (x86)\\Microsoft Visual Studio\\2022\\BuildTools"

$version    = false
$eyeproject = $currentdir

$msbuild    = "#{$vs}\\MSBuild\\Current\\Bin\\MSBuild.exe"
$solution   = "#{$eyeproject}\\vsproject\\instanteyedropper.sln"
$inno       = "#{$progs}\\Inno Setup 5\\ISCC.exe"
$innoscript = "#{$eyeproject}\\makeinstaller.iss"
$sevenz     = "C:\\Program Files\\7-Zip\\7z.exe"
$zipname    = "instant-eyedropper"
$newdir     = "#{$tmp}\\#{$zipname}"

class String
  def addq
    "\"#{self}\""
  end
end

####################################################################################################
def sysrun(command, debug)
  puts "\t" + "команда: ".bold.black + command.green if debug

  # Запускаем команду и захватываем вывод
  stdout, stderr, status = Open3.capture3(command)
  # Приводим вывод к UTF-8, заменяя некорректные символы
  output = (stdout + stderr).force_encoding("BINARY").encode("UTF-8", invalid: :replace, undef: :replace, replace: "?")

  if debug
    puts "\t" + "вывод:".bold.black
    output.split("\n").each { |line| puts "\t" + line.cyan }
    puts "\t" + "код завершения: ".bold.black + status.exitstatus.to_s.yellow
  end

  if status.success?
    puts "\t" + "ok".bold.green if debug
    return true
  else
    puts "\t" + "Команда провалилась с выводом:".bold.red
    output.split("\n").each { |line| puts "\t" + line.red }
    return false
  end
end

####################################################################################################

$debug = true if ARGV[0] == "debug"

# Проверка существования утилит
unless File.exist?($msbuild)
  puts "\t" + "MSBuild not found at #{$msbuild}".bold.red
  exit 1
end

unless File.exist?($solution)
  puts "\t" + "Solution file not found at #{$solution}".bold.red
  exit 1
end

unless File.exist?($inno)
  puts "\t" + "Inno Setup not found at #{$inno}".bold.red
  exit 1
end

unless File.exist?($sevenz)
  puts "\t" + "7-Zip not found at #{$sevenz}".bold.red
  exit 1
end

# Получение версии
version_regexp = Regexp.new('(\d+\.\d+\.\d+\.\d+)')
vlines = IO.popen("ruby version.rb").readlines.join.split("\n")
vlines.each do |line|
  if (m = line.match(version_regexp))
    $version = m[1]
    break
  end
end

if $version
  $version.gsub!(/\.\d+$/, '')

  # Скомпилировать проект
  @command = "#{$msbuild.addq} #{$solution.addq} /p:Configuration=Release"
  if sysrun(@command, $debug)
    puts "\t" + "compile project: " + "ok".bold.green unless $debug
  else
    puts "\t" + "compilation failed".bold.red
    exit 1
  end

  # Собрать инсталлятор
  @command = "#{$inno.addq} #{$innoscript.addq}"
  if sysrun(@command, $debug)
    puts "\t" + "build installer: " + "ok".bold.green unless $debug
  else
    puts "\t" + "building installer failed".bold.red
    exit 1
  end

  # Собрать ZIP
  $src = "#{$currentdir}/vsproject/output"
  # $zip = "#{$zipname}-#{$version}.zip"
  $zip = "#{$zipname}.zip"
  FileUtils.rm($zip) if File.exist?($zip)
  FileUtils.cp_r $src, $newdir

  @command = "#{$sevenz.addq} -tzip a #{$zip.addq} #{$newdir.addq}"
  if sysrun(@command, $debug)
    puts "\t" + "make zip: " + "ok".bold.green unless $debug
  else
    puts "\t" + "zip creation failed".bold.red
    exit 1
  end

  FileUtils.rm_rf($newdir) if File.exist?($newdir)
else
  puts "\t" + "Version not found".bold.red
  exit 1
end