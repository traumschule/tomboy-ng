unit SaveNote;

{
 * Copyright (C) 2017 David Bannon
 *
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files (the
 * "Software"), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to
 * the following conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
 * LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
 * OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
 * WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
}

{  This unit is responsible for saving a note in the Tomboy XML format.
    After creation, the class needs to be told the current FontNormal
	size and the CreatDate if any. If the supplied CreatDate is '', it will
	stamp it Now().
    All the work is done in the Save(..) function, it needs to be passed
	the name of a file (that may or may not exist) and the RichMemo its
	getting its content from.
}

{	HISTORY
	20170927 - added Hyperlink to blocks to be saved.
	2017/11/4 - replaced GetLocalTime() with one from TB_Sync, it puts minutes
				into the time offset figure, eg +11:00. Old notes written
				with previous vesions will fail with file sync until rewritten.
	2017/11/12  Added code to replace < and > with char codes.
}

{$mode objfpc}{$H+}

interface

uses
    Classes, SysUtils, KMemo, Graphics;

type

    { TBSaveNote }

 TBSaveNote = class

       private
            FSize : integer;
			Bold : boolean;
			Italics : boolean;
			HiLight : boolean;
			InList : boolean;
            KM : TKMemo;
            function AddTag(const FT : TFont; var Buff : ANSIString) : ANSIString;
			procedure BulletList(var Buff: ANSIString);
			function RemoveBadCharacters(const InStr: ANSIString): ANSIString;
            function SetFontXML(Size : integer; TurnOn : boolean) : string;
          	function Header() : ANSIstring;
         	Function Footer() : ANSIstring;
            function GetLocalTime():ANSIstring;
       public
            TimeStamp : string;
            Title : ANSIString;
      //      FontNormal : integer;		// Needs to be set after class created (could get from settings??)
            CreateDate : ANSIString;
         	procedure Save(FileName : ANSIString; KM1 : TKMemo);
    end;


implementation

uses FileUtil               // Graphics needed for font style defines
    ,LazUTF8
    ,Settings				// User settings and some defines across units.
    {$ifdef LINUX}, Unix {$endif} ;              // We call a ReReadLocalTime()



function TBSaveNote.SetFontXML(Size : integer; TurnOn : boolean) : string;
begin
    Result := '';
	if Size = Sett.FontHuge then
         if TurnOn then Result  := '<size:huge>' else Result  := '</size:huge>';
    if Size = sett.FontLarge then
         if TurnOn then Result  := '<size:large>' else Result  := '</size:large>';
    if Size = Sett.FontSmall then
         if TurnOn then Result  := '<size:small>' else Result  := '</size:small>';
end;


function TBSaveNote.AddTag(const FT : TFont; var Buff : ANSIString) : ANSIString;
begin
    // Important that we keep the tag order consistent. Good xml requires no cross over
    // tags. If the note is to be readable by Tomboy, must comply. (RTomboy does not care)
    // FontSize, HiLite, Ital, Bold, Bullet, BulletOff, BoldOff, ItalOff, HiLiteOff
    // Note Bullets are not dealt with here, have to be done later.

    // When Bold Turns OFF
    if (Bold and (not (fsBold in FT.Style))) then begin
        if FSize <> Sett.FontNormal then
            Buff := Buff + SetFontXML(FSize, false);
        if Hilight then Buff := Buff + '</highlight>';
        if Italics then Buff := Buff + '</italic>';
        Buff := Buff + '</bold>';
        if Italics then Buff := Buff + '<italic>';
        if Hilight then Buff := Buff + '<highlight>';
        if FSize <> Sett.FontNormal then
            Buff := Buff + SetFontXML(FSize, true);
        Bold := false;
    end;
    // When Italic turns OFF
    if (Italics and (not (fsItalic in FT.Style))) then begin
        if FSize <> Sett.FontNormal then
             Buff := Buff + SetFontXML(FSize, false);
        if Hilight then Buff := Buff + '</highlight>';
     	Buff := Buff + '</italic>';
        if Hilight then Buff := Buff + '<highlight>';
        if FSize <> Sett.FontNormal then
            Buff := Buff + SetFontXML(FSize, true);
        Italics := false;
    end;
    // When Highlight turns OFF
    if (HiLight and (not (FT.Color = HiColor))) then begin
        if FSize <> Sett.FontNormal then
            Buff := Buff + SetFontXML(FSize, false);
        Buff := Buff + '</highlight>';
        if FSize <> Sett.FontNormal then
            Buff := Buff + SetFontXML(FSize, true);
        HiLight := false;
    end;
    // When Font size changes
    if FSize <> FT.Size then begin
        Buff := Buff + SetFontXML(FSize, false);
        FSize := FT.Size;
        Buff := Buff + SetFontXML(FSize, true);
    end;
    // Highlight turns ON
    if ((not HiLight) and (FT.Color = HiColor)) then begin
        if FSize <> Sett.FontNormal then
             Buff := Buff + SetFontXML(FSize, false);
        Buff := Buff + '<highlight>';
        if FSize <> Sett.FontNormal then
             Buff := Buff + SetFontXML(FSize, true);
        HiLight := true;
    end;
    // Italic turns On
    if ((not Italics) and (fsItalic in FT.Style)) then begin
        if Hilight then Buff := Buff + '</highlight>';
        if FSize <> Sett.FontNormal then
        	Buff := Buff + SetFontXML(FSize, false);
        Buff := Buff + '<italic>';
        if FSize <> Sett.FontNormal then
             Buff := Buff + SetFontXML(FSize, true);
        if Hilight then Buff := Buff + '<highlight>';
        Italics := true;
    end;
    // Bold turns On
    if ((not Bold) and (fsBold in FT.Style)) then begin
        if Italics then Buff := Buff + '</italic>';
        if Hilight then Buff := Buff + '</highlight>';
        if FSize <> Sett.FontNormal then
             Buff := Buff + SetFontXML(FSize, false);
        Buff := Buff + '<bold>';
        if FSize <> Sett.FontNormal then
             Buff := Buff + SetFontXML(FSize, true);
         if Hilight then Buff := Buff + '<highlight>';
         if Italics then Buff := Buff + '<italic>';
        Bold := true;
    end;

    Result := Buff;
end;

procedure TBSaveNote.BulletList(var Buff : ANSIString);
begin
    Buff := '<list><list-item dir="ltr">' + Buff + '</list-item></list>';
end;

function TBSaveNote.RemoveBadCharacters(const InStr : ANSIString) : ANSIString;
var
   //Res : ANSIString;
   Index : longint = 1;
   Start : longint = 1;
begin
    Result := '';
   while Index <= UTF8length(InStr) do begin
   		if InStr[Index] = '<' then begin
             Result := Result + UTF8Copy(InStr, Start, Index - Start);
             Result := Result + '&lt;';
             inc(Index);
             Start := Index;
			 continue;
		end;
  		if InStr[Index] = '>' then begin
             Result := Result + UTF8Copy(InStr, Start, Index - Start);
             Result := Result + '&gt;';
             inc(Index);
             Start := Index;
			 continue;
		end;
        inc(Index);
   end;
   Result := Result + UTF8Copy(InStr, Start, Index - Start);
end;


procedure TBSaveNote.Save(FileName : ANSIString; KM1 : TKMemo);
var
   Buff : ANSIstring = '';
   OutStream:TFilestream;
   BlockNo : integer = 0;
   Block : TKMemoBlock;
   BlankFont : TFont;
 begin
    KM := KM1;
    FSize := 0;
	Bold := false;
 	Italics := False;
 	HiLight := False;
 	InList := false;     
            // Must deal with an empty list !
    try
        outstream :=TFilestream.Create(FileName, fmCreate);
        // Write and WriteBuffer accept a buffer, not a string !  Need to start at pos 1
        // when sending string or ANSIstring otherwise it uses first byte which makes it look like a binary file.
        // http://free-pascal-general.1045716.n5.nabble.com/Creating-text-files-with-TFileStream-td2824859.html
        Buff := Header();
        OutStream.Write(Buff[1], length(Buff));
        Buff := '';
        try
            repeat
                repeat
                    Block := KM1.Blocks.Items[BlockNo];
                    if Block.ClassNameIs('TKMemoTextBlock') then begin
                        AddTag(TKMemoTextBlock(Block).TextStyle.Font, Buff);
                        Buff := Buff + RemoveBadCharacters(Block.Text);
                    end;
                    if Block.ClassNameIs('TKMemoHyperlink') then begin
                        AddTag(TKMemoHyperlink(Block).TextStyle.Font, Buff);
                        Buff := Buff + RemoveBadCharacters(Block.Text);
                    end;
                    inc(BlockNo);
                    if BlockNo >= KM1.Blocks.Count then break;
				until KM1.Blocks.Items[BlockNo].ClassNameIs('TKMemoParagraph');
                if BlockNo >= KM1.Blocks.Count then break;
                if  TKMemoParagraph(KM1.Blocks.Items[BlockNo]).Numbering = pnuBullets then
                     BulletList(Buff);
                Buff := Buff + LineEnding;
                OutStream.Write(Buff[1], length(Buff));
                Buff := '';
                inc(BlockNo);
                if BlockNo >= KM1.Blocks.Count then break;
			until false;

            { At this point we may have unsaved content in Buff cos last block was not
              a Para. But it cannot be Bullet. If it was a Para, Buff is empty. But we
              could still have hanging xml tags. So either case, send it to add tag with
              an empty Font.
            }


            if not KM1.Blocks.LastBlock.ClassNameIs('TKMemoParagraph') then begin
                 // If we don't finish with a Para block, then we need to
                 // add it in as well.
                 BlankFont := TFont.Create();
                 BlankFont.Size := Sett.FontNormal;
                 BlankFont.Color := NormalColor;
                 BlankFont.Style := [];
                 AddTag(BlankFont, Buff);
                 Buff := Buff + KM1.Blocks.LastBlock.Text;
                 OutStream.Write(Buff[1], length(Buff));
                 BlankFont.Free;
            end;
            Buff := Footer();
            OutStream.Write(Buff[1], length(Buff));

         Except     { TODO 1 : Must test this to see what happens with an empty
         				list of blocks. Probably makes sense to not save anything
                        that does not have at least one TKMemotextBlock  }
            on EListError do begin
            	Buff := Footer();
            	OutStream.Write(Buff[1], length(Buff));
            end;
        end;
 	finally
        OutStream.Free;
    end;
end;


Function TBSaveNote.GetLocalTime():ANSIstring;
var
   ThisMoment : TDateTime;
   Res : ANSIString;
   Off : longint;
begin
   // Note this function is duplicated in TB_Sync.
    {$ifdef LINUX}
    ReReadLocalTime();    // in case we are near daylight saving time changeover
    {$endif}
    ThisMoment:=Now;
    Result := FormatDateTime('YYYY-MM-DD',ThisMoment) + 'T'
                   + FormatDateTime('hh:mm:ss.zzz"0000"',ThisMoment);
    Off := GetLocalTimeOffset();
    if (Off div -60) >= 0 then Res := '+'
	else Res := '-';
	if abs(Off div -60) < 10 then Res := Res + '0';
	Res := Res + inttostr(abs(Off div -60)) + ':';
       	if (Off mod 60) = 0 then
		Res := res + '00'
	else Res := Res + inttostr(abs(Off mod 60));
    Result := Result + res;

    { Result := FormatDateTime('YYYY-MM-DD',ThisMoment) + 'T'
                   + FormatDateTime('hh:mm:ss.z',ThisMoment) + '0000+'
                   + inttostr(GetLocalTimeOffset() div -60);   }
end;

Function TBSaveNote.Header() : ANSIstring;
var
   S1, S2, S3, S4 : ANSIString;
begin
  S1 := '<?xml version="1.0" encoding="utf-8"?>'#10'<note version="0.3" xmlns:link="';
  S2 := 'http://beatniksoftware.com/tomboy/link" xmlns:size="http://beatniksoftware.com/tomboy/size"';
  S3 := ' xmlns="http://beatniksoftware.com/tomboy">'#10'  <title>';
  S4 := '</title>'#10'  <text xml:space="preserve"><note-content version="0.1">';
  Result := S1 + S2 + S3 + Title + S4;
end;


Function TBSaveNote.Footer() : ANSIstring;
var
   S1, S2, S3, S4, S5 : string;

begin
  TimeStamp := GetLocalTime();   // get actual time date in format like Tomboy's
  S1 := '</note-content></text>'#10'  <last-change-date>';
  S2 := '</last-change-date>'#10'  <last-metadata-change-date>';
  S3 := '</last-metadata-change-date>'#10'  <create-date>';
  S4 := '</create-date>'#10'  <cursor-position>1</cursor-position>'#10'  <selection-bound-position>1</selection-bound-position>'#10;
  S5 := '  <width>1000</width>'#10'  <height>626</height>'#10'  <x>0</x>'#10'  <y>0</y>'#10'  <open-on-startup>False</open-on-startup>'#10'</note>';
  if CreateDate = '' then CreateDate := TimeStamp;
  Result := S1 + TimeStamp + S2 + TimeStamp + S3 + CreateDate + S4 + S5;
end;

end.

