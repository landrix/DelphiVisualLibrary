{***********************************************************}
{                     Codruts Icon Picker                   }
{                                                           }
{                         version 1.0                       }
{                           RELEASE                         }
{                                                           }
{                                                           }
{                                                           }
{                                                           }
{                                                           }
{                   -- WORK IN PROGRESS --                  }
{***********************************************************}

unit Cod.IconPicker;

interface
  uses
  Cod.ColorUtils,
  Winapi.Windows,
  Vcl.Forms,
  System.SysUtils,
  Cod.Visual.Button,
  Vcl.StdCtrls,
  System.Variants,
  System.Classes,
  Vcl.Graphics,
  Vcl.Controls,
  Cod.Visual.StandardIcons,
  Imaging.pngimage,
  Vcl.ControlList,
  Vcl.ExtCtrls,
  Vcl.Dialogs,
  System.Threading,
  Cod.Dialogs,
  PngFunctions,
  Cod.SysUtils,
  Vcl.TitleBarCtrls,
  ShellAPI;

  type
    CIconPicker = class(TComponent)
    public
      constructor Create(AOwner: TComponent); override;
      destructor Destroy; override;

    private
      FAuthor, FSite, FVersion: string;
      UI: TForm;

      FAllowNumbered: boolean;

      FileText: TEdit;
      CtrlList: TControlList;

      FTitleBar: TTitleBarPanel;

      FBrowseCaption: string;
      FFilePickCaption: string;
      FEnableThread: boolean;

      FNumber: TLabel;
      FImage: TImage;

      FIcons: TArray<TPngImage>;

      FFileName: string;
      FIndex: integer;

      FTitle: string;

      FIconSize: integer;
      FRowCount: integer;

      FCorespFile: string;

      FContentColor: TColor;
      FFontColor: TColor;

      LoadProc: ITask;

      BtYes: CButton;

      procedure EditKeyPress(Sender: TObject; var Key: Char);
      procedure EditKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
      procedure PressLoad(Sender: TObject);
      procedure ControlItemClicked(Sender: TObject);
      procedure ControlDraw(AIndex: Integer; ACanvas: TCanvas; ARect: TRect; AState: TOwnerDrawState);
      procedure BrowseClick(Sender: TObject);

      procedure CheckAllowYes;

      procedure FreeIconMem;

      procedure LoadIconsFromFile;
      procedure ActualLoad;

    published
      property Author: string Read FAuthor;
      property Site: string Read FSite;
      property Version: string Read FVersion;

      property EnableThreading: boolean read FEnableThread write FEnableThread default true;

      property CaptionFileName: string read FFilePickCaption write FFilePickCaption;
      property CaptionBrowse: string read FBrowseCaption write FBrowseCaption;

      property IconSize: integer read FIconSize write FIconSize;
      property RowCount: integer read FRowCount write FRowCount;

      property SelectedIndex: integer read FIndex write FIndex;
      property FileName: string read FFileName write FFileName;

      property FontColor: TColor read FFontColor write FFontColor;
      property FormColor: TColor read FContentColor write FContentColor;


      property NumberIcons: boolean read FAllowNumbered write FAllowNumbered;

      property Title: string read FTitle write FTitle;
    public
      function SelectID: integer;

      function GetImage: TPngImage;

      function Execute: boolean;
    end;

implementation

{ Icon Picker }

var
  regmode: integer = 0;

constructor CIconPicker.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FAuthor                       := 'Petculescu Codrut';
  FSite                         := 'https://www.codrutsoftware.cf';
  FVersion                      := '1.0';

  FAllowNumbered := true;

  FFileName := 'C:\Windows\System32\shell32.dll';

  FTitle := 'Icon Picker';

  FBrowseCaption := 'Browse';
  FFilePickCaption := 'File Location';

  FIconSize := 50;
  FRowCount := 3;

  FContentColor := clBtnFace;
  FFontColor := clBlack;

  FEnableThread := true;
end;

destructor CIconPicker.Destroy;
begin
  inherited Destroy;
end;

function GetFileIconCount(FileName: string): integer;
begin
  Result := ExtractIcon(0, PChar(FileName), Cardinal(-1));
end;

procedure GetFileIcon(FileName: string; var PngImage: TPngImage; IconIndex: word);
var
  ic: TIcon;
begin
  // Get TIcon
  ic := TIcon.Create;
  ic.Handle := ExtractAssociatedIcon(HInstance, PChar(FileName), IconIndex);
  ic.Transparent := true;

  // Convert to PNG
  PngImage := TPngImage.Create;

  ConvertToPNG(ic, PngImage);
end;

procedure CIconPicker.ActualLoad;
var
  filename: string;
  cnt: integer;
    I: Integer;
begin
    // Get File Icons
    filename := FileText.Text;

    if fileexists(FileText.Text) then
      begin
        CtrlList.ItemCount := 0;

        // Free memory
        FreeIconMem;

        //FIcons := GetAllFileIcons(filename);
        cnt := GetFileIconCount(FileName);

        SetLength(FIcons, cnt);

        for I := 0 to cnt - 1 do
          begin
            FIcons[I] := TPngImage.Create;

            try
              GetFileIcon(FileName, FIcons[I], I);
            except
              // Invalid icon handle
            end;

            CtrlList.ItemCount := I;
          end;

        CtrlList.ItemCount := length(FIcons);
      end;

    FCorespFile := filename;

    CheckAllowYes;
end;

procedure CIconPicker.BrowseClick(Sender: TObject);
var
  od: TOpenDialog;
begin
  od := TOpenDialog.Create(Self);
  try
    if od.Execute then
      begin
        FileText.Text := od.FileName;

        LoadIconsFromFile
      end;
  finally
    od.Free;
  end;
end;

procedure CIconPicker.CheckAllowYes;
begin
  BtYes.Enabled := fileexists(FileText.Text) and (CtrlList.ItemIndex <> -1) and (FileText.Text = FCorespFile);
end;

procedure CIconPicker.ControlDraw(AIndex: Integer; ACanvas: TCanvas;
  ARect: TRect; AState: TOwnerDrawState);
begin
  if FNumber <> nil then
    FNumber.Caption := AIndex.ToString;

  try
    FImage.Picture.Assign(FIcons[AIndex]);
  except

  end;
end;

procedure CIconPicker.ControlItemClicked(Sender: TObject);
begin
  CheckAllowYes;
end;

procedure CIconPicker.EditKeyPress(Sender: TObject; var Key: Char);
begin
  if Key = #13 then
    LoadIconsFromFile;
end;

procedure CIconPicker.EditKeyUp(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  CheckAllowYes;
end;

function CIconPicker.Execute: boolean;
begin
  Result := SelectID <> -1;

  FreeIconMem;
end;

procedure CIconPicker.FreeIconMem;
var
  I: integer;
begin
  // Free memory used by Icons
  for I := 0 to Length( FIcons ) - 1 do
    try
      if NOT FIcons[I].Empty then
        FIcons[I].Free;
    except

    end;
end;

function CIconPicker.GetImage: TPngImage;
begin
  if SelectID <> -1 then
    Result := FIcons[FIndex]
  else
    Result := nil;

  FreeIconMem;
end;

procedure PrepareCustomTitleBar(var TitleBar: TForm; const Background: TColor; Foreground: TColor);
var
  CB, CF, SCB, SCF: integer;
begin
  if GetColorSat(BackGround) < 100 then
    CB := 30
  else
    CB := -30;

  if GetColorSat(Foreground) < 100 then
    CF := 30
  else
    CF := -30;

  SCF := CF div 2;
  SCB := CF div 2;

  with TitleBar.CustomTitleBar do
    begin
      BackgroundColor := BackGround;
      InactiveBackgroundColor := ChangeColorSat(BackGround, CB);
      ButtonBackgroundColor := BackGround;
      ButtonHoverBackgroundColor := ChangeColorSat(BackGround, SCB);
      ButtonInactiveBackgroundColor := ChangeColorSat(BackGround, CB);
      ButtonPressedBackgroundColor := ChangeColorSat(BackGround, CB);

      ForegroundColor := Foreground;
      ButtonForegroundColor := Foreground;
      ButtonHoverForegroundColor := ChangeColorSat(ForeGround, SCF);
      InactiveForegroundColor := ChangeColorSat(Foreground, CF);
      ButtonInactiveForegroundColor := ChangeColorSat(Foreground, CF);
      ButtonPressedForegroundColor := ChangeColorSat(Foreground, CF);
    end;
end;

function CIconPicker.SelectID: integer;
const
  OK_WID = 60;
var
  HInc: integer;
begin
  HInc := 0;
  UI := TForm.Create(Application);
  with UI do begin

    Font.Name := 'Segoe UI';
    Font.Color := FFontColor;

    UI.Color := FContentColor;

    Width := 500;
    Height := 120 + 80 + {Rows} FIconSize * (FRowCount + 1) + TScrollbar.Create(nil).Height;
    Position := poDesigned;
    Left := Screen.Width div 2 - UI.Width div 2;
    Top := Screen.Height div 2 - UI.Height div 2;

    Caption := FTitle;

    BorderIcons := [biSystemMenu];

    BorderStyle := bsSingle;

    // Custom Title Bar
    if not (NTKernelVersion < 6.0) then
      begin
        FTitleBar := TTitleBarPanel.Create(UI);
        with FTitleBar do
          begin
            Parent := UI;

            HInc := Height;
          end;

        with UI.CustomTitleBar do
          begin
            Control := FTitleBar;

            Enabled := true;

            SystemButtons := false;
            SystemColors := false;

            //BackGroundColor := clRed;

            PrepareCustomTitleBar(UI, FContentColor, FFontColor);
          end;
      end;

    with CStandardIcon.Create(UI) do
      begin
        Parent := UI;

        SelectedIcon := ciconStar;

        Width := 30;
        Height := 30;

        Top := 10 + HInc;
        Left := 10;
      end;

    with TLabel.Create(UI) do begin
      Parent := UI;

      Caption := FTitle;

      Font.Style := [fsBold];
      Font.Name := 'Segoe UI';
      Font.Size := 18;

      Top := 10 + HInc;
      Left := 50;
    end;

    with TLabel.Create(UI) do begin
      Parent := UI;

      Caption := '                                                                             ';

      Font.Style := [fsUnderline];
      Font.Name := 'Segoe UI';
      Font.Size := 18;

      Top := 10 + HInc;
      Left := 50;
    end;

    // Create interface
    with TLabel.Create(UI) do begin
      Parent := UI;

      Caption := FTitle;

      Font.Name := 'Segoe UI';
      Font.Size := 18;

      Caption := FFilePickCaption;

      Top := 45 + HInc;
      Left := 30;
    end;

    FileText := TEdit.Create(UI);
    with FileText do
      begin
        Parent := UI;

        Font.Size := 12;

        Text := FileName;

        Color := FContentColor;

        Top := 80 + HInc;
        Left := 30;

        Width := UI.ClientWidth - 30 * 2 - OK_WID;

        OnKeyUp := EditKeyUp;
        OnKeyPress := EditKeyPress;
      end;

      with CButton.Create(UI) do
      begin
        Parent := UI;

        ButtonIcon := cicYes;

        Text := '';

        Width := OK_WID;
        Height := FileText.Height;

        Top := FileText.Top;

        Left := FileText.Left + FileText.Width + 3;

        OnClick := PressLoad;
      end;

    CtrlList := TControlList.Create(UI);
    with CtrlList do
      begin
        Parent := UI;

        Top := 120 + HInc;
        Left := 30;

        Color := FContentColor;

        BorderStyle := bsNone;
        ColumnLayout := cltMultiLeftToRight;

        CtrlList.ItemHeight := FIconSize;
        CtrlList.ItemWidth := FIconSize;

        Height := Ui.ClientHeight - Top - 80;
        Width := UI.ClientWidth - 30 * 2;

        OnItemClick := ControlItemClicked;
        OnBeforeDrawItem := ControlDraw;
      end;

    FImage := TImage.Create(UI);
    with FImage do
      begin
        Parent := UI;

        Align := alClient;

        Center := true;
        Proportional := true;

        CtrlList.AddControlToItem(FImage);
      end;

    if FAllowNumbered then
      begin
        FNumber := TLabel.Create(UI);
        with FNumber do
          begin
            Parent := UI;

            AutoSize := false;
            Top := CtrlList.ItemHeight - Height;

            Alignment := taRightJustify;

            Width := CtrlList.ItemWidth;

            Caption := 'Id';
            Left := 0;

            CtrlList.AddControlToItem(FNumber);
          end;
      end;

    // Create Buttons
    BtYes := CButton.Create(UI);
    with BtYes do begin
      Parent := UI;

      Text := ButtonLabels[2];
      ButtonIcon := cicYes;
      Top := Ui.Height - Height - 40 + HInc;
      Left := Ui.Width - Width - 10;

      Default := true;
      Cancel := false;

      Enabled := false;

      //TrueTransparency := false;

      ModalResult := mrOk;
    end;

    with CButton.Create(UI) do begin
      Parent := UI;

      Text := ButtonLabels[3];
      ButtonIcon := cicNo;
      Top := Ui.Height - Height - 40 + HInc;
      Left := Ui.Width - Width * 2 - 20;

      Default := false;
      Cancel := true;

      ModalResult := mrClose;
    end;

    with CButton.Create(UI) do begin
      Parent := UI;

      Text := 'Browse';
      ButtonIcon := cicSegoeFluent;

      BSegoeIcon := #$F12B;

      Top := Ui.Height - Height - 40 + HInc;
      Left := 20;

      OnClick := BrowseClick;
    end;

    LoadIconsFromFile;

    // Finish Dialog
    if ShowModal = mrOk then
    begin
      Result := CtrlList.ItemIndex;
      FIndex := Result;

      FileName := FileText.Text;
    end else Result := -1;
  end;
end;

procedure CIconPicker.LoadIconsFromFile;
begin
  if FEnableThread then
    begin
      if (LoadProc <> nil) and (LoadProc.Status = TTaskStatus.Running) then
        LoadProc.Cancel;

      LoadProc := TTask.Run(procedure
      begin
        ActualLoad;
      end);
    end
      else
        ActualLoad;
end;

procedure CIconPicker.PressLoad(Sender: TObject);
begin
  LoadIconsFromFile;
end;

end.
