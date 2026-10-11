#!/usr/bin/env ruby
require 'json'
root = File.expand_path('../../..', __dir__)
def check_png(path, size)
  data = File.binread(path)
  raise "Not PNG: #{path}" unless data.start_with?("\x89PNG\r\n\x1a\n".b)
  width, height = data[16,8].unpack('NN')
  raise "Wrong size #{path}: #{width}x#{height}" unless [width,height] == [size,size]
  raise "Unexpected alpha channel: #{path}" unless data.getbyte(25) == 2
end
%w[ios macos].each do |platform|
  directory = "#{root}/#{platform}/Runner/Assets.xcassets/AppIcon.appiconset"
  JSON.parse(File.read("#{directory}/Contents.json"))['images'].each do |image|
    check_png("#{directory}/#{image['filename']}", (image['size'].to_f * image['scale'].to_f).to_i)
  end
end
{'mdpi'=>48,'hdpi'=>72,'xhdpi'=>96,'xxhdpi'=>144,'xxxhdpi'=>192}.each do |density,size|
  check_png("#{root}/android/app/src/main/res/mipmap-#{density}/ic_launcher.png", size)
end
check_png("#{root}/web/favicon.png",32)
[192,512].each { |size| %w[Icon Icon-maskable].each { |name| check_png("#{root}/web/icons/#{name}-#{size}.png",size) } }
ico = File.binread("#{root}/windows/runner/resources/app_icon.ico")
raise 'Missing multi-size Windows icon' unless ico[0,6].unpack('vvv') == [0,1,6]
[16,32,48,64,128,256].each_with_index do |size,index|
  entry = ico[6 + index*16,16]
  bytes, offset = entry[8,8].unpack('VV')
  png = ico[offset,bytes]
  raise 'Bad ICO image' unless png[16,8].unpack('NN') == [size,size]
end
icon = JSON.parse(File.read("#{root}/tool/branding/icon.json"))
# Adaptive foreground must stay inside Android's central 66dp safe circle.
icon['lines'].each do |line|
  [[line[0],line[1]], [line[2],line[3]]].each do |x,y|
    raise 'Adaptive motif clips safe zone' if Math.hypot(x-54,y-54) + icon['stroke']/2.0 > 33
  end
end
lum = ->(hex) {
  rgb = hex.scan(/../).map { |channel| channel.to_i(16)/255.0 }
  rgb = rgb.map { |c| c <= 0.04045 ? c/12.92 : ((c+0.055)/1.055)**2.4 }
  rgb.zip([0.2126,0.7152,0.0722]).sum { |c,w| c*w }
}
a,b = [lum.call(icon['foreground']),lum.call(icon['background'])].sort
contrast = (b+0.05)/(a+0.05)
raise "Low icon contrast #{contrast}" unless contrast >= 4.5
puts "PASS launcher sizes, opaque Apple PNGs, Windows ICO, adaptive safe zone, contrast #{contrast.round(2)}:1"
