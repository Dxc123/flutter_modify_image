功能：
1.批量修改当前目录下所有图片的 MD5 值

2.无损压缩当前目录及其子目录下的所有图片
默认支持 PNG 和 JPEG 格式，通过参数 --type=png 或 --type=jpg 设置图片格式
添加 --quality 参数调整压缩质量（1-100），默认值为 80。

3.图片格式转换：

png -> webp

webp -> png



使用： 

执行 MD5 修改: flutter_modify_image md5

执行无损压缩 :
flutter_modify_image compress --type=png --quality=80



  

