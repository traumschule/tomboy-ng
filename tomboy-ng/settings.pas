unit settings;
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

{	This form represents all the settings and will have most (?) of the constants.

	Makes sense for all units to 'use' this unit, ideally in the implmentation
	section.
}

{	HISTORY
	2017/9/27 - Created

	2017/10/10 - added ability to set fonts to small, medium and big

	2017/10/15 - gave the setting form Tabs, lot less cluttered.

	2017/11/25 - added a button to notes path config to use the 'default' path
	that is, similar to what tomboy does. Code to make that path.

	2017/11/28 - put a ; after a line of windows only code.

}

{$mode objfpc}{$H+}

interface

uses
    Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, StdCtrls,
    Buttons, ComCtrls, ExtCtrls, Grids; // Types;

type TSyncOption = (AlwaysAsk, UseServer, UseLocal);	// Relating to sync clash

type

    { TSett }

    TSett = class(TForm)
			ButtDefaultNoteDir: TButton;
			ButtonShowBackUp: TButton;
			ButtonSaveConfig: TButton;

		ButtonSetNotePath: TButton;
		ButtonSetSynServer: TButton;
		CheckShowExtLinks: TCheckBox;
		CheckShowIntLinks: TCheckBox;
		GroupBox3: TGroupBox;
		GroupBox4: TGroupBox;
		GroupBox5: TGroupBox;
		Label1: TLabel;
		Label10: TLabel;
		Label11: TLabel;
		Label2: TLabel;
		Label3: TLabel;
		Label4: TLabel;
		Label5: TLabel;
		Label6: TLabel;
		Label7: TLabel;
		Label8: TLabel;
		Label9: TLabel;
		LabelSyncRepo: TLabel;
		LabelLocalConfig: TLabel;
		LabelNotesPath: TLabel;
		LabelSettingPath: TLabel;
		PageControl1: TPageControl;
		Panel1: TPanel;
		Panel2: TPanel;
		RadioAlwaysAsk: TRadioButton;
		RadioFile: TRadioButton;
		RadioFontBig: TRadioButton;
		RadioFontMedium: TRadioButton;
		RadioFontSmall: TRadioButton;
		RadioUseLocal: TRadioButton;
		RadioUseServer: TRadioButton;
		RadioServer: TRadioButton;
		SelectDirectoryDialog1: TSelectDirectoryDialog;
		StringGridBackUp: TStringGrid;
		TabBasic: TTabSheet;
		TabBackUp: TTabSheet;
		TabSnapshot: TTabSheet;
		TabSync: TTabSheet;
		TabDisplay: TTabSheet;
		procedure ButtDefaultNoteDirClick(Sender: TObject);
  procedure ButtonSaveConfigClick(Sender: TObject);
		procedure ButtonSetNotePathClick(Sender: TObject);
		procedure ButtonSetSynServerClick(Sender: TObject);
		procedure ButtonShowBackUpClick(Sender: TObject);
        { Called when ANY of the setting check boxes change so use can save. }
		procedure CheckReadOnlyChange(Sender: TObject);
        procedure FormCreate(Sender: TObject);
		procedure PageControl1Change(Sender: TObject);
   	private
 		procedure CheckConfigFile;
		procedure SetFontSizes;
		procedure SyncSettings;
    public
        FontSmall  : Integer;
     	FontLarge  : Integer;
     	FontHuge   : Integer;
     	FontTitle  : Integer;			// Dont set this to one of the other sizes !
     	FontNormal : Integer;
        { The directory expected to hold existing or new notes }
        NoteDirectory : string;
        LocalConfig : string;
        RemoteRepo  : string;
        SyncOption : TSyncOption;
        { Indicates we have done a config, not necessarily a valid one }
        HaveConfig : boolean;
        { Indicates user wants to see internal links }
        ShowIntLinks : boolean;
        { Says Notes should be treated as read only, a safe choice }
        NotesReadOnly : boolean;
    end;

var
    Sett : TSett;

const
     								// These const are used 'regionally' !
     // Font sizes, no text should be other than these sizes. Note TheFont and (FontNormal ?) are vars

  {   FSmall = 8;
     FLarge = 15;
     FHuge = 18;
     FTitle = 16;				// Dont set this to one of the other sizes !
     FNormal = 12;       }

    Placement = 45;				// where we position an opening window. Its, on average, 1.5 time Placement;

     HiColor      = clRed;
     NormalColor  = clDefault; 		// Must somewhere set this to be sure ?

     LinkScanRange = 50;		// when the user changes a Note, we search +/- around
     							// this value for any links that need adjusting.

  	SyncNotConfig = 'not configured';

implementation

{$R *.lfm}

{ TSett }

uses IniFiles,
    LazFileUtils,   // LazFileUtils needed for TrimFileName(), cross platform stuff;
    Note_Lister,	// List notes in BackUp and Snapshot tab
    MainUnit,		// So we can call IndexNotes() after altering Notes Dir
    syncGUI;

procedure TSett.SetFontSizes();
begin
	if RadioFontBig.checked then begin
    	FontSmall  := 9;
     	FontLarge  := 17;
     	FontHuge   := 20;
     	FontTitle  := 18;			// Dont set this to one of the other sizes !
     	FontNormal := 14;
	end;
    if RadioFontMedium.checked then begin
    	FontSmall  := 8;
 		FontLarge  := 15;
 		FontHuge   := 18;
 		FontTitle  := 16;			// Dont set this to one of the other sizes !
 		FontNormal := 12;
	end;
    if RadioFontSmall.Checked then begin
    	FontSmall  := 7;
 		FontLarge  := 13;
 		FontHuge   := 16;
 		FontTitle  := 14;			// Dont set this to one of the other sizes !
 		FontNormal := 10;
    end;

end;

	{ Make public things agree with internal ones. }
procedure TSett.SyncSettings();
begin
	if NoteDirectory <> '' then begin
        LabelNotespath.Caption := NoteDirectory;
        if NoteDirectory = '' then HaveConfig := False
        else HaveConfig := true;
        CheckShowIntLinks.enabled := true;
        ShowIntLinks := CheckShowIntLinks.Checked;
        SetFontSizes();
		if RadioAlwaysAsk.Checked then SyncOption := AlwaysAsk
        else if RadioUseLocal.Checked then SyncOption := UseLocal
        else if RadioUseServer.Checked then SyncOption := UseServer;
	end;
end;

	{ Read config file if it exists }
procedure TSett.CheckConfigFile();
var
	ConfigFile : TINIFile;
    // FileName : ANSIString;
    ReqFontSize : ANSIString;
begin
     // LabelSettingPath.Caption := GetAppConfigFile(False);
     LabelSettingPath.Caption := AppendPathDelim(GetAppConfigDir(False)) + 'tomboy-ng.cfg';
     LocalConfig := GetAppConfigDir(False);
     LabelLocalConfig.Caption := LocalConfig;
     if fileexists(LabelSettingPath.Caption) then begin
     	ConfigFile :=  TINIFile.Create(LabelSettingPath.Caption);
     	try
       		NoteDirectory := ConfigFile.readstring('BasicSettings', 'NotesPath', '');
            if 'true' = ConfigFile.readstring('BasicSettings', 'ShowIntLinks', 'true') then
                CheckShowIntLinks.Checked := true
            else CheckShowIntLinks.Checked := false;

            ReqFontSize := ConfigFile.readstring('BasicSettings', 'FontSize', 'medium');
            case ReqFontSize of
            	'big'    : RadioFontBig.Checked := true;
                'medium' : RadioFontMedium.Checked := true;
                'small'  : RadioFontSmall.Checked := true;
            end;
            case ConfigFile.readstring('SyncSettings', 'SyncOption', 'AlwaysAsk') of
                'AlwaysAsk' : begin SyncOption := AlwaysAsk; RadioAlwaysAsk.Checked := True; end;
                'UseLocal'  : begin SyncOption := UseLocal;  RadioUseLocal.Checked  := True; end;
                'UseServer' : begin SyncOption := UseServer; RadioUseServer.Checked := True; end;
			end;
			LabelSyncRepo.Caption := ConfigFile.readstring('SyncSettings', 'SyncRepo', SyncNotConfig);
            RemoteRepo := LabelSyncRepo.Caption;
		finally
            ConfigFile.free;
		end;
		SyncSettings();
	 end else begin
         LabelNotespath.Caption := 'Please Set a Path to a Notes Directory';
         NoteDirectory := '';
         HaveConfig := false;
     end;
end;

procedure TSett.FormCreate(Sender: TObject);
begin
    HaveConfig := false;
    NoteDirectory := 'Set me first please';
    labelNotesPath.Caption := NoteDirectory;
    CheckShowIntLinks.Checked := true;
    RadioFontMedium.checked := true;
    //SetFontSizes();
    CheckConfigFile();
    if (LabelSyncRepo.Caption = '') or (LabelSyncRepo.Caption = SyncNotConfig) then
        ButtonSetSynServer.Caption := 'Setup File Sync';
end;

procedure TSett.PageControl1Change(Sender: TObject);
begin

end;


	{ Save the settings, this will become auto in a later and braver release.}
procedure TSett.ButtonSaveConfigClick(Sender: TObject);
var
	ConfigFile : TINIFile;
begin
    ConfigFile :=  TINIFile.Create(LabelSettingPath.Caption);
    try
      ConfigFile.writestring('BasicSettings', 'NotesPath', NoteDirectory);
      ConfigFile.writestring('SyncSettings', 'SyncRepo', RemoteRepo);
      { if CheckReadOnly.Checked then
          ConfigFile.writestring('BasicSettings', 'ReadOnly', 'true')
      else ConfigFile.writestring('BasicSettings', 'ReadOnly', 'false');  }
      if CheckShowIntLinks.Checked then
          ConfigFile.writestring('BasicSettings', 'ShowIntLinks', 'true')
      else ConfigFile.writestring('BasicSettings', 'ShowIntLinks', 'false');

      if RadioFontBig.Checked then
          ConfigFile.writestring('BasicSettings', 'FontSize', 'big')
      else if RadioFontMedium.Checked then
          ConfigFile.writestring('BasicSettings', 'FontSize', 'medium')
      else if RadioFontSmall.Checked then
          ConfigFile.writestring('BasicSettings', 'FontSize', 'small');

		if RadioAlwaysAsk.Checked then
            ConfigFile.writestring('SyncSettings', 'SyncOption', 'AlwaysAsk')
        else if RadioUseLocal.Checked then
            ConfigFile.writestring('SyncSettings', 'SyncOption', 'UseLocal')
        else if RadioUseServer.Checked then
            ConfigFile.writestring('SyncSettings', 'SyncOption', 'UseServer');
    finally
    	ConfigFile.Free;
    end;
    ButtonSaveConfig.Enabled := False;
end;

procedure TSett.ButtDefaultNoteDirClick(Sender: TObject);
begin
    // GetEnvironmentVariable() seems utf8 ok ...
    {$IFDEF UNIX}
    NoteDirectory := GetEnvironmentVariable('HOME') + '/.local/share/tomboy-ng/';
    {$ENDIF}                // WARNING !!!!!!! Untested on OSX.
                            // WARNING !!!!!!! Untested windows code, take care
    {$IFDEF WINDOWS}
    NoteDirectory := GetEnvironmentVariable('APPDATA') + '\tomboy-ng\notes\';
    // %APPDATA%\Tomboy\notes\
    {$ENDIF}
    if not ForceDirectoriesUTF8(NoteDirectory) then
    	showmessage('Sorry, unable to create directory ' + NoteDirectory)
    else begin
    	LabelNotesPath.Caption := NoteDirectory;
		ButtonSaveConfig.Enabled := True;
    	CheckShowIntLinks.enabled := true;
    	SyncSettings();
    	RTSearch.IndexNotes();
	end;


end;

	{ Allow user to point to what they want to call their notes dir. If there
      are no notes there, pops up a warning and proceeds. }
procedure TSett.ButtonSetNotePathClick(Sender: TObject);
var
    Info : TSearchRec;
begin
	if SelectDirectoryDialog1.Execute then begin
		NoteDirectory := TrimFilename(SelectDirectoryDialog1.FileName + PathDelim);
        LabelNotesPath.Caption := NoteDirectory;
        if not FindFirst(NoteDirectory + '*.note', faAnyFile and faDirectory, Info)=0 then begin
           showmessage('That directory does not contain any notes. Thats OK, if I can make my own there.');
		end;
		ButtonSaveConfig.Enabled := True;
        CheckShowIntLinks.enabled := true;
        // CheckReadOnly.enabled := true;
        SyncSettings();
        RTSearch.IndexNotes();
	end;
end;

procedure TSett.ButtonSetSynServerClick(Sender: TObject);
begin
    if SelectDirectoryDialog1.Execute then begin
		RemoteRepo := TrimFilename(SelectDirectoryDialog1.FileName + PathDelim);
        if RemoteRepo = '' then RemoteRepo := SyncNotConfig;
        LabelSyncRepo.Caption := RemoteRepo;
        FormSync.NoteDirectory := NoteDirectory;
        FormSync.LocalConfig := LocalConfig;
        FormSync.RemoteRepo := RemoteRepo;
        FormSync.SetupFileSync := True;
        if mrOK = FormSync.ShowModal then begin
            RemoteRepo := LabelSyncRepo.Caption;
           	ButtonSaveConfigClick(self);
            ButtonSetSynServer.Caption:='Change File Sync';
        	// OK, user has tested, done first sync, is happy. Save this config.
        end else begin
        	LabelSyncRepo.Caption := SyncNotConfig;
            RemoteRepo := SyncNotConfig;
		end;
	end;
end;

procedure TSett.ButtonShowBackUpClick(Sender: TObject);
var
	NoteLister : TNoteLister;
begin
    NoteLister := TNoteLister.Create;
    NoteLister.WorkingDir:= NoteDirectory + 'Backup' + PathDelim;
    NoteLister.GetNotes();
    NoteLister.LoadStGrid(StringGridBackUp);
    NoteLister.Free;
end;

	{ Called when ANY of the setting check boxes change so use can save. }
procedure TSett.CheckReadOnlyChange(Sender: TObject);
begin
    ButtonSaveConfig.Enabled := True;
    SyncSettings();
end;


end.

