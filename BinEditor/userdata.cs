using Newtonsoft.Json.Linq;
using Newtonsoft.Json;
using System;
using System.Collections;
using System.Collections.Generic;
using System.Drawing;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading.Tasks;

namespace BinEditor
{
    public enum InstanceTypeEnum : uint
    {
        appItemDropParamLot = 0x6aa821d2,
        appItemDropParamTableItem = 0x32b6b787,
        appItemDropParamTable = 0x8fcd056d,
        appItemDropParam = 0xd4dd21f2,
        appItemDropData = 0x1428e659,
        appItemData = 0xC24AA782,
        appItemDataParam = 0x6111A04D,
        appItemArmorData = 0xA111A467,
        appItemArmorDataParam = 0xFA962830,

        viaphysicsUserData = 0xF767C93F,
        appAttackUserData = 0xE7BD8658,
        appAttackUserDataEnchantData = 0xF7CA2BAD,
        appAttackUserDataHitBackDirOptionData = 0x4D308118,
        appAttackUserDataStatusConditionAccumulationInfo = 0xC60DE11A,
        appAttackUserDataStatusConditionAtkData = 0x7D1BB74D,
        appAttackUserDataFriendHitData = 0xBF396190,
        appAttackUserDataSpecialParam = 0xF14FD085,
        viaphysicsRequestSetColliderUserData=0xC7516CCC
    };
    public class TypeDefineField
    {
        public int align;
        public string name;
        public string original_type;
        public int size;
        public string type;
        public bool array;
    }

    public class TypeDefine
    {
        public int CRC;
        public string Name ="";
        public int TypeEnum ;
        public List<TypeDefineField> fields=new List<TypeDefineField>();
    }
    public class userdata
    {
        public byte[] start_unknown = new byte[0x30];
        public RSZHeader rszheader=new RSZHeader();
        public List<int> objectTable=new List<int>();
        public List<InstanceTypeEnum> instanceinfos=new List<InstanceTypeEnum>();
        public List<ReadableItem> instances=new List<ReadableItem>();

        //
        public byte[] bytes=new byte[0];
        Dictionary<InstanceTypeEnum, uint> Enum2CRC = new Dictionary<InstanceTypeEnum, uint>();
        Dictionary<InstanceTypeEnum, Type> Enum2Class = new Dictionary<InstanceTypeEnum, Type>();
        Dictionary<Type, InstanceTypeEnum> Class2Enum = new Dictionary<Type, InstanceTypeEnum>();

        static Dictionary<string, TypeDefine> TypeDefineMap = new Dictionary<string, TypeDefine>();
        static Dictionary<int, TypeDefine> TypeDefineEnumMap = new Dictionary<int, TypeDefine>();

        public static void LoadTypeDefine()
        {
            var text = File.ReadAllText("E:\\OtherGame\\DragonDogma2\\RE_RSZ\\rszdd2.json");
            var doc = JsonConvert.DeserializeObject(text)! as JToken;
            foreach (JProperty pair in doc!.Children())
            {
                var name= pair.Value["name"]!.ToString();
                if (name == "") continue;
                var typeDefine=new TypeDefine();
                typeDefine.CRC = (int)new System.ComponentModel.Int32Converter().ConvertFromString("0x"+pair.Value["crc"]!.ToString())!;
                typeDefine.TypeEnum = (int)new System.ComponentModel.Int32Converter().ConvertFromString("0x" + pair.Name!.ToString())!;
                typeDefine.Name = pair.Value["name"]!.ToString();
                foreach (var _field in pair.Value["fields"]!.ToArray<JToken>())
                {
                    var field=new TypeDefineField();
                    field.align = _field["align"]!.Value<int>();
                    field.size = _field["size"]!.Value<int>();
                    field.array = _field["array"]!.Value<bool>();
                    field.original_type = _field["original_type"]!.Value<string>()!;
                    field.type = _field["type"]!.Value<string>()!;
                    field.name = _field["name"]!.Value<string>()!;
                    typeDefine.fields.Add(field);
                }
                TypeDefineMap.Add(typeDefine.Name, typeDefine);
                TypeDefineEnumMap.Add(typeDefine.TypeEnum, typeDefine);
            }
        }
        public userdata()
        {
        }
        public void IncreaseAllIdx(int offset)
        {
            for (int i = 0; i < objectTable.Count; i++)
                objectTable[i] = objectTable[i] + offset;
            foreach(var ins in instances)
                ins.IncreaseValueInListInt(offset);
        }
        public void Read(string filename) 
        {
            bool isRCOL = filename.Contains(".rcol.");
            int offset = 0x0;
            bytes = File.ReadAllBytes(filename);
            
            //0~0x30
            System.Array.Copy(bytes,start_unknown, start_unknown.Length);
            offset = start_unknown.Length;
            if (isRCOL)
            {
                int rszheaderoffset= BitConverter.ToInt32(bytes,0x38);
                offset = rszheaderoffset;
            }

            //rszheader
            var rszheaderStart = offset;
            rszheader.Read(bytes,ref offset);

            if (rszheader.magic != 0x5a5352)
                throw new Exception();

            //objectTable
            for(int i = 0; i < rszheader.objectCount; i++)
            {
                objectTable.Add(BitConverter.ToInt32(bytes, offset));
                offset += 0x4;
            }

            //instanceInfo
            offset = rszheaderStart + (int)rszheader.instanceOffset;
            {
                offset += 0x8;
                for (; offset < bytes.Length;)
                {
                    uint id = BitConverter.ToUInt32(bytes, offset);
                    if (id == 0 || instanceinfos.Count()>=rszheader.instanceCount-1)//去掉开头的null
                        break;
                    instanceinfos.Add((InstanceTypeEnum)id);
                    uint CRC = BitConverter.ToUInt32(bytes, offset + 0x4);
                    if (!Enum2CRC.ContainsKey((InstanceTypeEnum)id))
                        Enum2CRC[(InstanceTypeEnum)id] = CRC;
                    offset += 0x8;
                }
                offset += 0x4;
            }

            //instancez
            offset = (int)rszheader.userdataOffset + rszheaderStart;
            foreach (var instanceInfo in instanceinfos)
            {
                var typeDefine = TypeDefineEnumMap[(int)instanceInfo];
                var tmp = new ReadableItem();
                tmp!.Read(bytes, ref offset,typeDefine);
                instances.Add(tmp);
            }
        }
        public void Write(string filename)
        {
            byte[] tmpbytes = new byte[bytes.Length * 100];
            int tmpoffset = 0;

            //start
            System.Array.Copy(start_unknown, tmpbytes, start_unknown.Length);
            tmpoffset += start_unknown.Length;

            //rszheader
            if (instanceinfos.Count+1 != rszheader.instanceCount)
            {
                var delta = instanceinfos.Count+1 - rszheader.instanceCount;
                rszheader.instanceCount = instanceinfos.Count+1;
                rszheader.userdataOffset += delta * 0x8;
                rszheader.dataOffset += delta * 0x8;
            }
            rszheader.Write(tmpbytes,ref tmpoffset);

            //objecttable
            {
                var otbytes=objectTable.SelectMany(BitConverter.GetBytes).ToArray();
                System.Array.Copy(otbytes,0x0, tmpbytes,tmpoffset, otbytes.Length);
                tmpoffset += otbytes.Length;
            }

            //instanceinfo
            {
                tmpoffset += 0x8;
                uint[] iitmp = new uint[instanceinfos.Count * 2];
                for (int i = 0; i < instanceinfos.Count; ++i)
                {
                    iitmp[i * 2] = (uint)instanceinfos[i];
                    iitmp[i * 2 + 1] = Enum2CRC[instanceinfos[i]];
                }
                System.Buffer.BlockCopy(iitmp,0x0, tmpbytes,tmpoffset, iitmp.Length*4);
                tmpoffset += iitmp.Length * 4;
                tmpoffset += 0x4;
            }

            foreach(var instance in instances) 
                instance.Write(tmpbytes,ref tmpoffset);

            var cuttedbytes=new byte[tmpoffset];
            System.Array.Copy(tmpbytes, cuttedbytes, tmpoffset);


            if(false)
            for(int i = 0;i<tmpoffset;i++)
                if (cuttedbytes[i] != bytes[i])
                {
                    Console.WriteLine("1");
                }
            File.WriteAllBytes(filename, cuttedbytes);
        }
    }
}
