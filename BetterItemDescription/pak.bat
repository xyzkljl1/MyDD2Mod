del itemdetail.msg.22
echo F|xcopy .\_itemdetail.msg.22 .\itemdetail.msg.22
REngine_msg_Tool.exe -i -lng en itemdetail.msg.22
del itemdetail.msg.22
move itemdetail.msg.22.new itemdetail.msg.22

REngine_msg_Tool.exe -i -lng zhCN itemdetail.msg.22
del itemdetail.msg.22
move itemdetail.msg.22.new itemdetail.msg.22

REngine_msg_Tool.exe -i -lng zhTW itemdetail.msg.22
del itemdetail.msg.22
move itemdetail.msg.22.new itemdetail.msg.22

