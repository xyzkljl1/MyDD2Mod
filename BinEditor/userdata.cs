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
    };
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

        public userdata()
        {
            //init Enum2Class/Class2Enum
            var enumnames = Enum.GetNames(typeof(InstanceTypeEnum));
            var values = Enum.GetValues(typeof(InstanceTypeEnum));
            int ct = 0;
            foreach (InstanceTypeEnum v in values)
            {
                var enumname = enumnames[ct];
                ct++;

                var typename = $"BinEditor.{enumname.Substring(3)}";
                var type = Type.GetType(typename);
                Enum2Class.Add(v, type!);
                Class2Enum.Add(type!, v);
            }
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
            int offset = 0x0;
            bytes = File.ReadAllBytes(filename);
            
            //0~0x30
            System.Array.Copy(bytes,start_unknown, start_unknown.Length);
            offset = start_unknown.Length;

            //rszheader
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
            offset =0x30+ (int)rszheader.instanceOffset;
            {
                offset += 0x8;
                for (; offset < bytes.Length;)
                {
                    uint id = BitConverter.ToUInt32(bytes, offset);
                    if (id == 0)
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
            offset = (int)rszheader.userdataOffset + 0x30;
            foreach (var instanceInfo in instanceinfos)
            {
                var type = Enum2Class[(InstanceTypeEnum)instanceInfo];
                var tmp = Activator.CreateInstance(type) as ReadableItem;
                tmp!.Read(bytes, ref offset);
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
