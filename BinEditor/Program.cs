﻿using System;
using System.ComponentModel;
using System.Net.Http.Json;
using System.Reflection;
using System.Reflection.PortableExecutable;
using System.Runtime.InteropServices;
using System.Text.Json.Nodes;
using System.Text.Json.Serialization;
using System.Xml.Linq;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using BinEditor;
using System.Text;
using Microsoft.VisualBasic;
using Microsoft.International.Converters.TraditionalChineseToSimplifiedConverter;
using System.Configuration;
using System.Text.RegularExpressions;
using static System.Net.Mime.MediaTypeNames;

if (false)
{
    SetItemSellPrice("E:\\OtherGame\\DragonDogma2\\REtool\\HigherItemSellPrice\\natives\\stm\\appsystem\\item\\itemdata\\itemdata.user.2", 0x60, 491);
    SetItemSellPrice("E:\\OtherGame\\DragonDogma2\\REtool\\HigherItemSellPrice\\natives\\stm\\appsystem\\item\\itemdata\\itemarmordata.user.2", 0x74, 361);
    SetItemSellPrice("E:\\OtherGame\\DragonDogma2\\REtool\\HigherItemSellPrice\\natives\\stm\\appsystem\\item\\itemdata\\itemweapondata.user.2", 0x88, 138);

    SetItemSellPrice("E:\\OtherGame\\DragonDogma2\\REtool\\HigherItemSellPrice10\\natives\\stm\\appsystem\\item\\itemdata\\itemdata.user.2", 0x60, 491, 10);
    SetItemSellPrice("E:\\OtherGame\\DragonDogma2\\REtool\\HigherItemSellPrice10\\natives\\stm\\appsystem\\item\\itemdata\\itemarmordata.user.2", 0x74, 361, 10);
    SetItemSellPrice("E:\\OtherGame\\DragonDogma2\\REtool\\HigherItemSellPrice10\\natives\\stm\\appsystem\\item\\itemdata\\itemweapondata.user.2", 0x88, 138, 10);
}

Dictionary<string, string> itemId2Name = new Dictionary<string, string>();
if (false)
{
    var text = File.ReadAllText("E:\\OtherGame\\DragonDogma2\\MyDD2Mod\\ITEM_NAME_LOOKUP.json");
    var doc = JsonConvert.DeserializeObject(text)! as JObject;
    foreach (JProperty pair in doc["chS"])
    {
        itemId2Name[pair.Name] = pair.Value.ToString();
    }
    //dlc2593210 宠爱吊坠;其它dlc物品有同款在游戏本体，不需要管
    itemId2Name.Add("606","宠爱吊坠");
}
if (false)
{
    var bytes = File.ReadAllBytes("E:\\OtherGame\\DragonDogma2\\REtool\\re_chunk_000\\natives\\stm\\appsystem\\item\\itemmixdata\\itemmixdata.user.2");
    int ct = BitConverter.ToInt32(bytes, 0x1b0c);
    int offset = 0x0740;
    for (int i = 0; i < ct; i++)
    {
        var itemId = BitConverter.ToInt32(bytes, offset + 0x0);
        var num = BitConverter.ToInt32(bytes, offset + 0x4);

        string msg = itemId2Name[$"{itemId}"];
        msg = $"{msg}*{num} ";

        offset += 0x8;
        var mat_a = readIdList(bytes, ref offset);
        var mat_b = readIdList(bytes, ref offset);
        msg = $"{msg} = {mat_a} + {mat_b}";
        bool nosame = BitConverter.ToBoolean(bytes, offset);
        if (nosame)
            msg += "(*)";
        offset += 0x4;
        Console.WriteLine(msg);
    }
}

//higher drop rate
if(false)
{
    foreach (string _filename in new[] { "enemydefaultitemdropdata.user.2", "enemyitemdropdata.user.2" })
    {
        string original_filename = $"E:\\OtherGame\\DragonDogma2\\REtool\\re_chunk_000\\natives\\stm\\appsystem\\item\\itemdropdata\\{_filename}";
        string filename = $"E:\\OtherGame\\DragonDogma2\\REtool\\HigherDropRate2\\natives\\stm\\appsystem\\item\\itemdropdata\\{_filename}";
        var data = new userdata();
        data.Read(original_filename);
        for (int i = 0; i < data.instances.Count; ++i)
        {
            var instance = data.instances[i];
            var param = instance as ItemDropParam;
            if (param != null)
            {
                if (param.lotList.Count > 1)
                {
                    foreach (var lotid in param.lotList)
                    {
                        var lot = data.instances[lotid - 1] as ItemDropParamLot;
                        if (lot is null) throw new Exception();
                        if (lot.Num > 0)
                        {
                            //有几个包含两个非空掉落的lot的param但是两个lot都为50，所以都设100没有影响
                            lot.Num = lot.Num*2;
                            lot.Rate = 100;
                        }
                        else
                        {
                            lot.Rate = 0;
                        }
                    }

                }
            }
        }
        data.Write(filename);
    }
}

//drop ferrystone
if(false)
{
    //0x192be280 :drops 4064
    var ignoreItemId = new HashSet<int> { };
    //var ignoreItemId = new HashSet<int> { 4064 };
    foreach (string _filename in new[] { "enemydefaultitemdropdata.user.2", "enemyitemdropdata.user.2" })
    {
        string original_filename = $"E:\\OtherGame\\DragonDogma2\\REtool\\re_chunk_000\\natives\\stm\\appsystem\\item\\itemdropdata\\{_filename}";
        string filename = $"E:\\OtherGame\\DragonDogma2\\REtool\\DropFerryStone\\natives\\stm\\appsystem\\item\\itemdropdata\\{_filename}";
        var data = new userdata();
        data.Read(original_filename);

        var newItem = new ItemDropParamTableItem();
        newItem.Id = 80;
        newItem.Num = 1;
        newItem.Rate = 8;
        newItem.Attr = 0;
        data.instances.Insert(0, newItem);
        data.instanceinfos.Insert(0, InstanceTypeEnum.appItemDropParamTableItem);
        data.IncreaseAllIdx(1);
        if(false)
        foreach (var instance in data.instances)
            if(instance as ItemDropParamTable is not null)
            {
                var table = instance as ItemDropParamTable;
                bool ignore = false;
                foreach (var itemId in table.itemList)
                {
                    var item = data.instances[itemId-1] as ItemDropParamTableItem;
                    if(ignoreItemId.Contains(item!.Id))
                        ignore=true;
                }
                table!.itemList.Add(1);
            }
        //if (false)
        {
            for (int i = 0; i < data.instances.Count; ++i)
            {
                var instance = data.instances[i];
                var param = instance as ItemDropParam;
                bool x=false;
                if (param != null)
                {
                    foreach (var tableId in param.tableList)
                    {
                        var table = data.instances[tableId - 1] as ItemDropParamTable;
                        //if(table.itemList.Count==1)
                        foreach (var itemId in table.itemList)
                        {
                            var item = data.instances[itemId - 1] as ItemDropParamTableItem;
                            if (item.Id == 4064)
                            {
                                x = true;                                
                                foreach (var lotId in param.lotList)
                                {
                                    var lot = data.instances[lotId - 1] as ItemDropParamLot;
                                    Console.WriteLine($"{lot.Num}/{lot.Rate}");
                                }
                                Console.WriteLine("1111");
                            }
                        }
                    }
                    if(x)
                    {
                        foreach (var tableId in param.tableList)
                        {
                            var table = data.instances[tableId - 1] as ItemDropParamTable;
                            foreach (var xItemId in table.itemList)
                            {
                                var xItem = data.instances[xItemId - 1] as ItemDropParamTableItem;
                                Console.WriteLine($"{xItem.Id}/{xItem.Rate}/{xItem.Rate}");
                            }
                            Console.WriteLine("---");
                        }
                        x =false;
                    }
                }
            }

        }

        //data.Write(filename);
    }
}

//"e980ba7a-aa46-453b-8561-950ad0d09fcb" 835
//
if (false)
{
    string original_filename = $"E:\\OtherGame\\DragonDogma2\\REtool\\re_chunk_000\\natives\\stm\\event\\talkevent\\talkeventresource\\common.user.2";
    string filename = $"E:\\OtherGame\\DragonDogma2\\REtool\\StorageAnywhere\\natives\\stm\\event\\talkevent\\talkeventresource\\common.user.2";
    var data = new userdata();
    data.Read(original_filename);

}

//random drop
if (false)
{
    foreach (string _filename in new[] { "enemydefaultitemdropdata.user.2", "enemyitemdropdata.user.2" })
    {
        string original_filename = $"E:\\OtherGame\\DragonDogma2\\REtool\\re_chunk_000\\natives\\stm\\appsystem\\item\\itemdropdata\\{_filename}";
        string filename = $"E:\\OtherGame\\DragonDogma2\\REtool\\CompleteRandomDrop\\natives\\stm\\appsystem\\item\\itemdropdata\\{_filename}";
        var data = new userdata();
        data.Read(original_filename);
        /*
        foreach (var instance in data.instances)
            if (instance as ItemDropParamTableItem is not null)
            {
                var item=instance as ItemDropParamTableItem;
                if(item.Id==0xf5)
                {
                    if(item!.Attr!=1)
                    {
                        ;
                    }
                }
                if (item!.Attr != 0&&item!.Id!=0xfb&&item!.Id!=0xf5)
                    ;
            }*/

        List<int> stdlist = new List<int>();
        foreach (var itemId in itemId2Name.Keys)
            //if(Int32.Parse(itemId)!=606)
            if (Int32.Parse(itemId) == 398)
        {
            var newItem = new ItemDropParamTableItem();
            newItem.Id = Int32.Parse(itemId);
            newItem.Num = 1;
            newItem.Rate = 1;
            newItem.Attr = 0;
            data.instances.Insert(0, newItem);
            data.instanceinfos.Insert(0, InstanceTypeEnum.appItemDropParamTableItem);
            stdlist.Add(stdlist.Count+1);
        }
        data.IncreaseAllIdx(stdlist.Count);
        foreach (var instance in data.instances)
            if (instance as ItemDropParamTable is not null)
            {
                var table = instance as ItemDropParamTable;
                table!.itemList = stdlist;
            }

        data.Write(filename);
    }
}


//item detail
if(false)
{
    List<int> itemIdByOrder = new List<int>();
    {
        var text = File.ReadAllText("E:\\OtherGame\\DragonDogma2\\MyDD2Mod\\ItemLookUpForMsg.json");
        var doc = JsonConvert.DeserializeObject(text)! as JToken;
        foreach (JProperty pair in doc)
            itemIdByOrder.Add(Int32.Parse(pair.Name));
    }

    var itemdata = new userdata();
    itemdata.Read("E:\\OtherGame\\DragonDogma2\\REtool\\re_chunk_000\\natives\\stm\\appsystem\\item\\itemdata\\itemdata.user.2");
    var armordata = new userdata();
    armordata.Read("E:\\OtherGame\\DragonDogma2\\REtool\\re_chunk_000\\natives\\stm\\appsystem\\item\\itemdata\\itemarmordata.user.2");

    foreach (string lng in new[] { "en","zhCN","zhTW" })
    {
        bool isCN = lng == "zhCN" || lng == "zhTW";
        string msgFileName = $"itemdetail.msg.22.{lng}.txt";
        //带_的为原版
        var filename = $"E:\\OtherGame\\DragonDogma2\\MyDD2Mod\\BetterItemDescription\\_{msgFileName}";
        var MsgLines=File.ReadAllLines(filename);
        if (MsgLines.Length != itemIdByOrder.Count)
            throw new Exception();
        List<string> newMsgLines= new List<string>();
        for(int i=0;i<itemIdByOrder.Count;++i)
        {
            string additionalMsg = "";
            var id = itemIdByOrder[i];
            if (id < 1000)//item
            {
                foreach(var _item in itemdata.instances)
                {
                    var item = _item as ItemDataParam;
                    if (item is not null)
                        if (item.Id == id)
                        {
                            if (item.healWhiteHP > 0)
                                additionalMsg += isCN ? $"治疗{item.healWhiteHP}生命。" : $"Heal {item.healWhiteHP}.";
                            if (item.healBlackHP > 0)
                                additionalMsg += isCN ? $"恢复{item.healBlackHP}生命上限。" : $"Heal {item.healBlackHP} MaxHP.";
                            if (item.healStam > 0)
                                additionalMsg += isCN ? $"恢复{item.healStam}体力。" : $"Restore {item.healStam} Stamina.";
                        }

                }
            }
            else//armor
            {
                foreach (var _item in armordata.instances)
                {
                    var item = _item as ItemArmorDataParam;
                    if (item is not null&&item.Id == id
                        &&item.eqcat==6)//rings
                    {
                        if (item.special_ext != 0)
                        {
                            if (item.special_ext == 1)
                                additionalMsg += isCN ? $"增加{item.specialValue1}生命上限。" : $"Add {item.specialValue1} MaxHP.";
                            else if (item.special_ext == 2)
                                additionalMsg += isCN ? $"增加{item.specialValue1}体力上限。" : $"Add {item.specialValue1} Max Stamina.";
                            else if (item.special_ext == 3)
                                additionalMsg += isCN ? $"增加{item.specialValue1}负重。" : $"Add {item.specialValue1} Carry Weight.";
                            else if (item.special_ext == 4)
                                additionalMsg += isCN ? $"增加{item.specialValue1}/{item.specialValue2}/{item.specialValue3}生命上限/体力/负重。" : $"Add {item.specialValue1}/{item.specialValue2}/{item.specialValue3} Max HP/Stamina/Weight.";
                            else if (item.special_ext == 5)
                                additionalMsg += isCN ? $"增加{item.specialValue1}物理攻击。" : $"Add {item.specialValue1} Physic ATK.";
                            else if (item.special_ext == 6)
                                additionalMsg += isCN ? $"增加{item.specialValue1}魔法攻击。" : $"Add {item.specialValue1} Magic ATK.";

                            else if (item.special_ext == 7)
                                additionalMsg += isCN ? $"{item.specialValue1}%额外经验(可叠加)。" : $"{item.specialValue1}% More Exp(stackable).";
                            else if (item.special_ext == 8)
                                additionalMsg += isCN ? $"{item.specialValue1}%额外JP(可叠加)。" : $"{item.specialValue1}% More JP(stackable).";

                            else if (item.special_ext == 9)
                                additionalMsg += isCN ? $"击倒敌人回复{item.specialValue1}。" : $"Heal {item.specialValue1} on kill.";
                            else if (item.special_ext == 10)
                                additionalMsg += isCN ? $"增加{item.specialValue1}快速咏唱。" : $"{item.specialValue1} spell cast speed";
                            else if (item.special_ext == 11)//+25速度-20生命
                                additionalMsg += isCN ? $"减少{item.specialValue2}生命上限，增加{item.specialValue1}快速咏唱。" : $"{item.specialValue1} spell cast speed.<lf>Lose {item.specialValue2} MaxHP";

                            else if (item.special_ext == 12)
                                additionalMsg += isCN ? $"增加{item.specialValue1}强韧度。" : $"Add {item.specialValue1} Robustness";

                            else if (item.special_ext == 13)
                                additionalMsg += isCN ? $"减少{item.specialValue1}持盾体力消耗。" : $"Add {item.specialValue1} stamina cost holding shield";


                            else if (item.special_ext == 14)//10秒buff，攻击力不显示在面板
                                additionalMsg += isCN ? $"{item.specialValue2}秒内获得{item.specialValue1}攻击力。" : $"Gain {item.specialValue1} ATK in {item.specialValue2} seconds";
                            //15无参数
                            else if (item.special_ext == 16)
                                additionalMsg += isCN ? $"一次受伤超过{item.specialValue1}%生命上限时，<lf>{item.specialValue2}秒内回复少量体力。" : $"Slight heal for {item.specialValue2} seconds when <lf>taken damage over {item.specialValue1}% MaxHP";
                            else if (item.special_ext == 17)//未测试
                                additionalMsg += isCN ? $"生命值少于{item.specialValue1}%时<lf>获得{item.specialValue2}攻击力" : $"Gain {item.specialValue2} ATK when HP under {item.specialValue1}%";
                             
                            else if (item.special_ext == 18)//未测试
                                additionalMsg += isCN ? $"生命值不少于{item.specialValue1}%时<lf>获得{item.specialValue2}攻击力" : $"Gain {item.specialValue2} ATK when HP over {item.specialValue1}%";

                            else if (item.special_ext == 21)
                                additionalMsg += isCN ? $"增加{item.specialValue1}体力回复。" : $"Add {item.specialValue1} Stamina Recover";
                            else if (item.special_ext == 22)
                                additionalMsg += isCN ? $"增加{item.specialValue1}破韧。" : $"Add {item.specialValue1} stagger and knock down ability";
                            //23无参数
                            else if (item.special_ext == 24)//数值=25/25，所以无所谓顺序
                                additionalMsg += isCN ? $"增加{item.specialValue1}/{item.specialValue2}%造成/受到的伤害。" : $"{item.specialValue1}/{item.specialValue2}% More/Less Damage.";

                            else if (item.special_ext == 25)
                                additionalMsg += isCN ? $"增加{item.specialValue1}%伤害。" : $"{item.specialValue1}% More Damage";
                            else if (item.special_ext == 26)//未测试，根据前几个推断
                                additionalMsg += isCN ? $"{item.specialValue2}秒内获得{item.specialValue1}防御力。" : $"Gain {item.specialValue1} Def in {item.specialValue2} seconds.";
                            else if (item.special_ext == 27)
                                additionalMsg += isCN ? $"增加{item.specialValue1}恢复量。" : $"Add {item.specialValue1} recover amount.";
                            //28 29无参数
                            else if (item.special_ext == 30)
                                additionalMsg += isCN ? $"增加{item.specialValue1}。" : $"Add {item.specialValue1}.";
                        }
                        if (item.phyDef > 0)
                            additionalMsg += isCN ? $"增加{item.phyDef}物理防御。" : $"Add {item.phyDef} Physic DEF.";
                        if (item.magicDef > 0)
                            additionalMsg += isCN ? $"增加{item.magicDef}魔法防御。" : $"Add {item.magicDef} Magic DEF.";
                        if (item.slashDefRate > 0)
                            additionalMsg += isCN ? $"获得{item.slashDefRate}%斩击减伤。" : $"Gain {item.slashDefRate}% slash DEF rate.";
                        if (item.strikeDefRate > 0)
                            additionalMsg += isCN ? $"获得{item.strikeDefRate}%打击减伤。" : $"Gain {item.strikeDefRate}% strike DEF rate.";
                        //def是受伤抗性，res是异常抵抗
                        if (item.fireDef > 0)
                            additionalMsg += isCN ? $"增加{item.fireDef}火抗。" : $"Add {item.fireDef} Fire DEF.";
                        if (item.iceDef > 0)
                            additionalMsg += isCN ? $"增加{item.iceDef}冰抗。" : $"Add {item.iceDef} Ice DEF.";
                        if (item.thunderDef > 0)
                            additionalMsg += isCN ? $"增加{item.thunderDef}雷抗。" : $"Add {item.thunderDef} Thunder DEF.";
                        if (item.lightDef > 0)
                            additionalMsg += isCN ? $"增加{item.lightDef}光抗。" : $"Add {item.lightDef} Light DEF.";
                        if (item.darkDef > 0)
                            additionalMsg += isCN ? $"增加{item.darkDef}暗抗。" : $"Add {item.darkDef} Dark DEF.";
                        if (item.fireRes > 0)
                            additionalMsg += isCN ? $"增加{item.fireRes}该异常抵抗。" : $"Add {item.fireRes} Resist.";
                        if (item.iceRes > 0)
                            additionalMsg += isCN ? $"增加{item.iceRes}该异常抵抗。" : $"Add {item.iceRes} Resist.";
                        if (item.thunderRes > 0)
                            additionalMsg += isCN ? $"增加{item.thunderRes}该异常抵抗。" : $"Add {item.thunderRes} Resist.";
                        if (item.shakeResRate > 0)
                            additionalMsg += isCN ? $"增加{item.shakeResRate}该异常抵抗。" : $"Add {item.shakeResRate} Resist.";
                        if (item.blowResRate > 0)
                            additionalMsg += isCN ? $"增加{item.blowResRate}该异常抵抗。" : $"Add {item.blowResRate} Resist.";
                        if (item.posionRes > 0)
                            additionalMsg += isCN ? $"增加{item.posionRes}该异常抵抗。" : $"Add {item.posionRes} Resist.";
                        if (item.sleepRes > 0)
                            additionalMsg += isCN ? $"增加{item.sleepRes}该异常抵抗。" : $"Add {item.sleepRes} Resist.";
                        if (item.silentRes > 0)
                            additionalMsg += isCN ? $"增加{item.silentRes}该异常抵抗。" : $"Add {item.silentRes} Resist.";
                        if (item.stoneRes > 0)
                            additionalMsg += isCN ? $"增加{item.stoneRes}该异常抵抗。" : $"Add {item.stoneRes} Resist.";
                        if (item.waterRes > 0)
                            additionalMsg += isCN ? $"增加{item.waterRes}该异常抵抗。" : $"Add {item.waterRes} Resist.";
                        if (item.oilRes > 0)
                            additionalMsg += isCN ? $"增加{item.oilRes}该异常抵抗。" : $"Add {item.oilRes} Resist.";

                    }

                }
            }

            if(lng=="zhTW")
                additionalMsg = ChineseConverter.Convert(additionalMsg, ChineseConversionDirection.SimplifiedToTraditional);
            if (additionalMsg!="")
            {
                newMsgLines.Add($"{MsgLines[i]}<lf>{additionalMsg}");
            }
            else
                newMsgLines.Add(MsgLines[i]);
        }

        File.WriteAllLines($"E:\\OtherGame\\DragonDogma2\\MyDD2Mod\\BetterItemDescription\\{msgFileName}",newMsgLines,Encoding.Unicode);
    }
}

userdata.LoadTypeDefine();

//ghidra decompiler
if (false)
{
    var TypeDefineFuncAddressName2FuncName = new Dictionary<string, string>();
    {
        var lines = File.ReadAllLines("H:\\SteamLibrary\\steamapps\\common\\Dragons Dogma 2\\dump.idc");
        foreach (var line in lines)
            if (line.Contains("MakeNameEx"))
            {
                var tmp = line.Substring(line.IndexOf('(') + 1);
                var address = tmp.Substring(0, tmp.IndexOf(",")).Replace("0x", "");
                tmp = tmp.Substring(tmp.IndexOf("\"") + 1);
                var name = tmp.Substring(0, tmp.IndexOf("\""));
                TypeDefineFuncAddressName2FuncName[$"FUN_{address.ToLower()}"] = name;
            }
    }
    { 
        var lines = File.ReadAllLines("E:\\OtherGame\\DragonDogma2\\reverse\\1.c");
        Regex rg = new Regex("FUN_[0-9a-f]+");
        int ct = 0;
        for (int i = 0; i < lines.Length; ++i)
        {
            var line = lines[i];
            var matches = rg.Matches(line);
            foreach (Match match in matches)
                if (TypeDefineFuncAddressName2FuncName.ContainsKey(match.Value))
                {
                    lines[i] = line.Remove(match.Index, match.Length).Insert(match.Index, TypeDefineFuncAddressName2FuncName[match.Value]);
                }
            ct++;
            if(ct%100==0)
                Console.WriteLine($"{ct}_{lines.Length}");
        }
        File.WriteAllLines("E:\\OtherGame\\DragonDogma2\\reverse\\replaced.c", lines);
    }
}
if(false)
{
    var lines=File.ReadAllLines("E:\\OtherGame\\DragonDogma2\\reverse\\replaced.c");
    int last_line = 0;
    int file_ct = 1;
    for (int i = 0; i < lines.Length; ++i)
    {
        var line = lines[i];
        if(line.StartsWith("void"))
        {
            if(i-last_line>=3000)
            {
                File.WriteAllLines($"E:\\OtherGame\\DragonDogma2\\reverse\\split\\{file_ct}.c", lines[last_line..i]);
                file_ct++;
                last_line = i;
            }
        }
    }
    if (lines.Length-last_line>0)
    {
        File.WriteAllLines($"E:\\OtherGame\\DragonDogma2\\reverse\\split\\{file_ct}.c", lines[last_line..lines.Length]);
    }
}
if(true)
{
    var map = new Dictionary<string, Dictionary<string, string>>();
    var short2fullname = new Dictionary<string, string>();
    var class2parent=new Dictionary<string, string>();
    {
        var lines = File.ReadAllLines("H:\\SteamLibrary\\steamapps\\common\\Dragons Dogma 2\\address.list");
        foreach (var line in lines)
        {
            var eles=line.Split(' ');
            if (eles.Length==5)
            {
                var classname = eles[0];
                if(classname.StartsWith("app") || classname.StartsWith("via"))
                {
                    {
                        var shortname = classname;
                        while (shortname.Contains("."))
                            shortname = shortname.Substring(shortname.IndexOf(".") + 1);
                        if (!short2fullname.ContainsKey(classname))
                            short2fullname[shortname] = classname;
                        else
                            short2fullname[classname] = "_Dup";
                    }

                    var valuename = eles[1].Replace("<", "_").Replace(">", "_");
                    var address = eles[2];
                    var valuetype = eles[3];
                    var parent = eles[4];
                    if (!map.ContainsKey(classname))
                        map[classname] = new Dictionary<string, string>();
                    map[classname][address]=valuename;
                    map[classname][valuename] = valuetype;
                    class2parent[classname] = parent;
                }
            }
        }
    }
    {
        var filename = "E:\\OtherGame\\DragonDogma2\\reverse\\manual\\checkthre.cs";
        var lines = File.ReadAllLines(filename);
        Regex regex = new Regex("\\*\\((float|uint|byte|char|int|ulonglong|longlong|undefined[0-9]*)[ ]*[\\*]*\\*\\)\\(([a-zA-Z_\\.]+)[ ]*\\+[ ]*(0x[0-9a-f]+)\\)");
        for(int j=0;j<4 ;j++)
            for (int i = 0; i < lines.Length; ++i)
            {
                var line = lines[i];
                foreach (Match match in regex.Matches(line))
                {
                    var varname = match.Groups[2].Value.Split(".");
                    var address = match.Groups[3].Value;
                    if (!short2fullname.ContainsKey(varname[0])) break;
                    var classname = short2fullname[varname[0]];
                    foreach(var middlename in varname[1..])
                    {
                        if (!map.ContainsKey(classname)) break;
                        if (!map[classname].ContainsKey(middlename))
                        {
                            var parent = classname;
                            while (class2parent.ContainsKey(parent)&& !map[parent].ContainsKey(middlename))
                                parent = class2parent[parent];
                            if (map.ContainsKey(parent) && map[parent].ContainsKey(middlename))
                                classname = map[parent][middlename];
                            else
                                classname = "..";
                        }
                        else
                            classname = map[classname][middlename];
                    }
                    if (!map.ContainsKey(classname)) break;
                    while (!map[classname].ContainsKey(address))
                    {
                        var parent = class2parent[classname];
                        classname= parent;
                        if (!map.ContainsKey(parent)) break;
                    }
                    if (!map.ContainsKey(classname)) break;

                    var dest = $"{match.Groups[2].Value}.{map[classname][address]}";
                    lines[i] = line.Replace(match.Value,dest);
                }
            }
        File.WriteAllLines(filename,lines);

    }
}

//ActionRate
if (false)
{
    //    var y=IsInitialized();
    var jsonDoc = new Dictionary<string,object>();
    var jobEnumDictionary = new HashSet<string>()
    {
    "job01",
    "job02",
    "job03",
    "job04",
    "job05",
    "job06",
    "job07",
    "job08",
    "job09",
    "job10",
    "jobmagic",
    };
    var debugText = "";
    foreach (var file in Directory.GetFiles("E:\\OtherGame\\DragonDogma2\\rcolLess\\"))
        //if(file.Contains("1720828575-1911543801.rcol.10"))
    {
        var filinfo = new FileInfo(file);
        var filename=filinfo.Name;
        while (filename.LastIndexOf('.')>0)
            filename=filename.Substring(0,filename.LastIndexOf("."));

        foreach(var jobEnum in jobEnumDictionary)
            if(filename.Contains(jobEnum))
            {
                filename = jobEnum; break;
            }

        if (!jsonDoc.ContainsKey(filename))
            jsonDoc[filename] = new Dictionary<string, object>();
        var jsonJobObject= (jsonDoc[filename] as Dictionary<string, object>)!;

        var userdata = new userdata();
        userdata.Read(file);
        var tmpstr = "";
        var hint2ARDic = new Dictionary<string, float>();   
        foreach (var instance in userdata.instances)
            if (instance.typeDefine.Name.Equals("app.AttackUserData"))
            {
                //SameAttackObjectID和SameFrameHitID似乎要么为空要么等于SameAttackID
                var satkID = (instance.dynamicValues["SameAttackID"] as int?);

                var atkIDkey=satkID.ToString();
                if(!jsonJobObject.ContainsKey(atkIDkey))
                    jsonJobObject[atkIDkey]= new List<object>();
                var jsonAtkIDObject= (jsonJobObject[atkIDkey] as List<object>)!;

                var hint= (instance.dynamicValues["v0"] as string)!;
                var ar= (instance.dynamicValues["ActionRate"] as float?);
                if (hint2ARDic.ContainsKey(hint)&& hint2ARDic[hint]==ar)//相同的值只写一遍
                    continue;
                hint2ARDic[hint] = (float)ar!;


                var actionObject = new Dictionary<string, object>();               

                actionObject["Hint"] = hint;
                actionObject["ActionRate"] = ar;
                //actionObject["Path"] = $"{filename}.{atkIDkey}.{actionKey}";
                jsonAtkIDObject.Add(actionObject);
                //stupid
                jsonAtkIDObject.Sort((l,r) => { return ((l as Dictionary<string, object>)!["Hint"] as string)!.CompareTo((r as Dictionary<string, object>)!["Hint"] as string); } );
                for(int i=0;i<jsonAtkIDObject.Count;i++)
                    (jsonAtkIDObject[i] as Dictionary<string, object>)!["Path"]= $"{filename}.{atkIDkey}.{i}";
            }
        if (jsonJobObject.Count() == 0) jsonDoc.Remove(filename);

        if (true)
        {
            var enum2strDic=new Dictionary<int, string>() {
                {-1,"" },
                {0,"" },
            { 1,"Wind_M"},
            { 2,"Wind_L"},
            { 3,"Quake_S"},
            { 4,"Quake_L"},
            { 5,"Hitback_S"},
            { 6,"Hitback_M"},
            { 7,"Hitback_L"},
            { 8,"Hitback_LL"},
            { 9,"Hitback_LLL"},
            { 10,"Hitdown_S"},
            { 11,"HitdownQuick_S"},
            { 12,"Hitdown_L"},
            { 13,"HitdownQuick_L"},
            { 14,"Slam_S"},
            { 15,"Slam_L"},
            { 16,"Upper_S"},
            { 17,"Upper_L"},
            { 18,"Blown_S"},
            { 19,"Blown_L"},
            { 20,"Dialog_Blown_S"},
            { 21,"Dialog_Blown_L"},
            { 22,"FlashFlood"},
            { 23,"Num"},
            };
            var list=new Dictionary<string,string> ();
            foreach (var instance in userdata.instances)
                if (instance.typeDefine.Name.Equals("app.AttackUserData"))
                {
                    var name = (instance.dynamicValues["v0"] as string)!;
                    var ar = (instance.dynamicValues["ActionRate"] as float?);
                    var lean = enum2strDic[(int)(instance.dynamicValues["DamageTypeLean"] as int?)];
                    var blow = enum2strDic[(int)(instance.dynamicValues["DamageTypeBlown"] as int?)];
                    var t = $"{ar}/{(instance.dynamicValues["DmgReactionRate"] as float?)}/{lean}/{blow}";

                    var enchantObjectIndex = (int)(instance.dynamicValues["Enchant"] as int?)!;
                    var enchantObject = userdata.instances[enchantObjectIndex-1];
                    var a = (float)(enchantObject.dynamicValues["PhysicalFactor"] as float?)!;
                    var b = (float)(enchantObject.dynamicValues["MagicalFactor"] as float?)!;
                    var c = (float)(enchantObject.dynamicValues["StatusDamageFactor"] as float?)!;

                    if (Math.Abs(a - 1) > 0.01)
                        t += $"(PhyEnchantFactor:{a})";
                    if (Math.Abs(b - 1) > 0.01)
                        t += $"(MagEnchantFactor:{b})";
                    if (Math.Abs(c - 1) > 0.01)
                        t += $"(StatusEnchantFactor:{c})";

                    if (!list.ContainsKey(name))
                        list[name] = t;
                    else if (list[name]!=t)
                    {
                        while (list.ContainsKey(name))
                            name += "_";
                        list[name] = t;
                    }
                }
            if(list.Count!=0)
                debugText += filename + "\n\n";
            foreach (var pair in list)
                debugText +=$"{pair.Key} : {pair.Value}\n";

        }
    }
    File.WriteAllText("E:\\OtherGame\\DragonDogma2\\MyDD2Mod\\PlayerActionRate3.txt", debugText);
    var jsonText = JsonConvert.SerializeObject(jsonDoc);
    //Console.WriteLine(jsonText);
    //File.WriteAllText("E:\\OtherGame\\DragonDogma2\\MyDD2Mod\\SkillDescription\\reframework\\data\\SkillDescription.Para.json", jsonText);
}

string readIdList(byte[] bytes, ref int offset)
{
    string ret = "";
    var ct = BitConverter.ToInt32(bytes, offset);
    for (int j = 0; j < ct; j++)
    {
        offset += 0x4;
        int itemId = BitConverter.ToInt32(bytes, offset);
        var name = itemId2Name[$"{itemId}"];
        if (ret != "")
            ret = $"{ret}/{name}";
        else
            ret = name;
    }
    offset += 0x4;
    return ret;
}


void SetItemSellPrice(string filename, int itemStructLength, int ct, int rate = 1)
{
    var bytes = File.ReadAllBytes(filename);
    var len = bytes.Length;
    var header = getHeader(bytes, 0x30);
    if (header.magic != 0x5a5352)
        return;

    int offset = (int)header.userdataOffset + 0x30;
    for (int i = 0; i < ct; i++)
    //for(;offset<len;offset+=itemStructLength)
    {
        var idx = BitConverter.ToInt32(bytes, offset + 0x0);
        var buyprice = BitConverter.ToInt32(bytes, offset + 0x20);
        var sellprice = BitConverter.ToInt32(bytes, offset + 0x24);

        sellprice = buyprice * rate;
        for (int j = 0; j < 4; j++)
        {
            bytes[offset + 0x24 + j] = BitConverter.GetBytes(sellprice)[j];
        }
        offset += itemStructLength;
        Console.WriteLine($"{idx}:{buyprice}/{sellprice}");
    }
    File.WriteAllBytes(filename, bytes);
    Console.WriteLine("Done");
}


RSZHeader getHeader(byte[] bytes, int offset)
{
    int size = Marshal.SizeOf(typeof(RSZHeader));
    IntPtr buffer = Marshal.AllocHGlobal(size);
    Marshal.Copy(bytes, offset, buffer, size);
    var header = (RSZHeader)Marshal.PtrToStructure(buffer, typeof(RSZHeader))!;
    Marshal.FreeHGlobal(buffer);
    return header;
}
