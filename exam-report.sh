#!/bin/bash

<<'COMMENT'
知识点：
xdotool getmouselocation #得到鼠标点位置
COMMENT

#数据初始化区域
init-data(){
    WID=`xdotool search --name "^win.*Oracle" | head -2`
    ttt=`echo "$WID" | wc -l`
    if [[ $ttt != 1 ]];then
        echo "符合截图程序查询条件的实例数不为1，请修正查询条件后重试！==>$ttt"
        exit
    fi

    echo "wid==>$WID"

    #一次循环只处理一个班级好了
    GRADECODE=00000 #年级编号，前3位为学校编号，后两位为入学年份
    CLASSCODE=00 #班级在年级的编号，不足两位前面补0
    SUBJECTCOUNT=8 #年级最大科目数量
    STUDENTCOUNT=55 #班级最大学生人数
    #分辨率在1600x900时，浏览器刷新键的位置
    REFRESH_X=76
    REFRESH_Y=92
}


#获取图像数据
#参数 WID 窗口进程号
#参数 STUDENTNO 学号
get-jpg-data(){
    if [[ ! $WID ]];then
        echo '$WID is null'
        exit
    fi
    
    #刷新键的位置
    xx0=$((REFRESH_X))
    yy0=$((REFRESH_Y))

    #用户名及密码输入位置
    xx1=$((702+xx0))
    yy1=$((403+yy0))
    xdotool mousemove $xx1 $yy1 click 1
    xdotool type $STUDENTNO
    sleep 1
    xdotool key Tab
    sleep 1
    xdotool type 123456
    sleep 1
    xdotool key Tab Tab Return
    sleep 10
    xdotool key Return
    import -frame -window $WID jtmp_$STUDENTNO.jpg
    sleep 1
    xdotool mousemove $xx0 $yy0 click 1
    sleep 1
    xdotool key Return
    sleep 5
}


#分割名字及各科目分数
#参数 STUDENTNO 学号
#参数 SUBJECTCOUNT 科目数量
crop-name-score(){
    srcimg=jtmp_$STUDENTNO.jpg

    convert  $srcimg -crop 90x35+145+117 tmp_name.jpg
    convert -monochrome tmp_name.jpg tmp_name.jpg
    convert -negate tmp_name.jpg tmp_name.jpg

    xcount=5
    ycount=$(($SUBJECTCOUNT/$xcount+1))

    index=0
    for yyy in `seq $ycount`;do
        ppy=$((356+(yyy-1)*141))
        for xxx in `seq $xcount`;do
            index=$((index+1))
            if [[ $index -gt $SUBJECTCOUNT ]];then
                break
            fi
            
            ppx=$((173+235*(xxx-1)))
            convert $srcimg -crop 68x28+$ppx+$ppy tmp_$index.jpg
        done
    done
}


#清除图片背景的噪点
#参数 源图片 目标图片
remove-background-noise(){
convert \
$1 -threshold 60% \
-define connected-components:verbose=true \
-define connected-components:area-threshold=5 \
-define connected-components:mean-color=true \
-connected-components 8 \
$2

}

#图像转数字或文字
#参数 STUDENTNO 学号
#参数 SUBJECTCOUNT 科目数量
convert-pics-txt(){

    if [[ ! -f jtmp_${STUDENTNO}.jpg ]];then
       echo "$STUDENTNO 不存在000!"
        return
    fi

    #文件小于指定长度
    flength=`du -b jtmp_${STUDENTNO}.jpg | awk '{print $1}'`
    if [[ $flength -lt 91873 ]];then
        echo "$STUDENTNO 不存在111!"
        return
    fi
    
    #图片分割
    crop-name-score
    #先去除噪点
    remove-background-noise tmp_name.jpg tmp_name.jpg
    for index in `seq $SUBJECTCOUNT`;do
        remove-background-noise tmp_$index.jpg tmp_$index.jpg
    done
    
    tesseract -l chi_sim tmp_name.jpg gtmp -psm 7
    
    echo "$STUDENTNO">$STUDENTNO.txt
        cat gtmp.txt>>$STUDENTNO.txt
    
    for index in `seq $SUBJECTCOUNT`;do
        tesseract tmp_${index}.jpg gtmp -psm 7
        sed -i 's/[^.0-9]\+//g' gtmp.txt
        cat gtmp.txt>>$STUDENTNO.txt
    done
    sed -i ':a;N;s/\n/\t/;ba;' $STUDENTNO.txt
    sed -i 's/[\t\s ]\+/\t/g' $STUDENTNO.txt
    sed -i 's/^[\t\s ]\+//g' $STUDENTNO.txt
}


#第一步，先下载图片
download-pics(){
    init-data
    for index in `seq -f '%02g' 1 ${STUDENTCOUNT}`;do #seq -f '%02g' 1 52
        STUDENTNO="$GRADECODE$CLASSCODE$index"
        echo $STUDENTNO
        get-jpg-data
    done
}

#第二步，图片传文字，依赖参数 SUBJECTCOUNT STUDENTNO
convert-pics-txt-all(){
    init-data
    #从第6位开始取9位
    for index in `ls jtmp_?????????.jpg|awk '{print substr($1,6,9)}'`;do
        STUDENTNO="$index"
        convert-pics-txt
    done
}

#第三步，汇总成绩
create-report(){
    init-data
    echo>report.txt
    #从第1位开始取9位
    for index in `ls ?????????.txt|awk '{print substr($1,1,9)}'`;do
        STUDENTNO="$index"
        if [[ ! -f jtmp_$STUDENTNO.jpg ]];then
            continue
        fi
        cat $STUDENTNO.txt>>report.txt
    done
}


test01(){
    echo>total.txt
    for index in `seq -f '%02g' 1 49`;do
        STUDENTNO="$GRADECODE$CLASSCODE$index"
        if [[ ! -f $STUDENTNO.txt ]];then
            continue
        fi
        cat $STUDENTNO.txt>>total.txt
    done
}

test00(){
    echo>total.txt
    for index in `ls $GRADECODE0???.txt|awk '{print substr($1,1,9)}'`;do
        if [[ ! -f $index.txt ]];then
            continue
        fi
        cat $index.txt>>total.txt
    done
    return
    
    for index in `ls jtmp_$GRADECODE0???.jpg|awk '{print substr($1,6,9)}'`;do
        STUDENTNO="$index"
        convert-pics-txt
    done
    return
    
    for index in `seq 8`;do
        cp $index/jtmp_$GRADECODE0$index??.jpg ./
    done

    return
    
    for index in `seq -f '%02g' 1 49`;do
        STUDENTNO="$GRADECODE$CLASSCODE$index"
        convert-pics-txt
    done
}

test(){
    init-data
    for index in `seq -f '%02g' 30 30`;do #seq -f '%02g' 1 52
        STUDENTNO="$GRADECODE$CLASSCODE$index"
        get-jpg-data
        convert-pics-txt
    done
}

testppp(){
    ttt=tmp_?.jpg
    ls -al $ttt
}

$1
