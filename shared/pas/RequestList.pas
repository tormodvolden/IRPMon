Unit RequestList;

{$IFDEF FPC}
{$MODE Delphi}
{$ENDIF}

Interface

Uses
  Classes, Generics.Collections,
  IRPMonDll,
  AbstractRequest,
  IRPMonRequest,
  DataParsers;

Type
  TRequestList = Class;
  TRequestListOnRequestProcessed = Procedure (ARequestList:TRequestList; ARequest:TDriverRequest; Var AStore:Boolean);
  TRequestList = Class
    Private
      FOnRequestProcessed : TRequestListOnRequestProcessed;
      FFilterDisplayOnly : Boolean;
      FAllRequests : TList<TDriverRequest>;
      FRequests : TList<TDriverRequest>;
      FDriverMap : TDictionary<Pointer, WideString>;
      FDeviceMap : TDictionary<Pointer, WideString>;
      FFileMap : TDictionary<Pointer, WideString>;
      FProcessMap : TDictionary<Cardinal, WideString>;
      FParsers : TObjectList<TDataParser>;
    Protected
      Function GetCount:Integer;
      Function GetItem(AIndex:Integer):TDriverRequest;
      Procedure SetFilterDisplayOnly(AValue:Boolean);
    Public
      Constructor Create;
      Destructor Destroy; Override;

      Function RefreshMaps:Cardinal;
      Procedure Clear;
      Function ProcessBuffer(ABuffer:PREQUEST_GENERAL):Cardinal;

      Procedure SaveToStream(AStream:TStream; AFormat:ERequestLogFormat; ACompress:Boolean = False);
      Procedure LoadFromStream(AStream:TStream; ARequireHeader:Boolean = True);
      Procedure SaveToFile(AFileName:WideString; AFormat:ERequestLogFormat; ACompress:Boolean = False);
      Procedure LoadFromFile(AFileName:WideString; ARequireHeader:Boolean = True);
      Function GetTotalCount:Integer;
      Procedure Reevaluate;

      Function GetDriverName(AObject:Pointer; Var AName:WideString):Boolean;
      Function GetDeviceName(AObject:Pointer; Var AName:WideString):Boolean;
      Function GetFileName(AObject:Pointer; Var AName:WideString):Boolean;
      Function GetProcessName(AProcessId:Cardinal; Var AName:WideString):Boolean;

      Property FilterDisplayOnly : Boolean Read FFilterDisplayOnly Write SetFilterDisplayOnly;
      Property Parsers : TObjectList<TDataParser> Read FParsers Write FParsers;
      Property Count : Integer Read GetCount;
      Property Items [Index:Integer] : TDriverRequest Read GetItem; Default;
      Property OnRequestProcessed : TRequestListOnRequestProcessed Read FOnRequestProcessed Write FOnRequestProcessed;
    end;

Implementation

Uses
  Windows,
  SysUtils,
  IRPRequest,
  BinaryLogHeader,
  FastIoRequest,
  DriverUnloadRequest,
  IRPCompleteRequest,
  StartIoRequest,
  AddDeviceRequest,
  XXXDetectedRequests,
  FileObjectNameXXXRequest,
  ProcessXXXRequests,
  ImageLoadRequest;

Constructor TRequestList.Create;
begin
Inherited Create;
FRequests := TList<TDriverRequest>.Create;
FAllRequests := TList<TDriverRequest>.Create;
FDriverMap := TDictionary<Pointer, WideString>.Create;
FDeviceMap := TDictionary<Pointer, WideString>.Create;
FFileMap := TDictionary<Pointer, WideString>.Create;
FProcessMap := TDictionary<Cardinal, WideString>.Create;
RefreshMaps;
end;

Destructor TRequestList.Destroy;
begin
FProcessMap.Free;
FFileMap.Free;
FDriverMap.Free;
FDeviceMap.Free;
Clear;
FAllRequests.Free;
FRequests.Free;
Inherited Destroy;
end;

Function TRequestList.RefreshMaps:Cardinal;
Var
  I, J : Integer;
  count : Cardinal;
  pdri : PPIRPMON_DRIVER_INFO;
  dri : PIRPMON_DRIVER_INFO;
  tmp : PPIRPMON_DRIVER_INFO;
  pdei : PPIRPMON_DEVICE_INFO;
  dei : PIRPMON_DEVICE_INFO;
begin
Result := IRPMonDllSnapshotRetrieve(pdri, count);
If Result = ERROR_SUCCESS Then
  begin
  FDriverMap.Clear;
  FDeviceMap.Clear;
  tmp := pdri;
  For I := 0 To count - 1 Do
    begin
    dri := tmp^;
    FDriverMap.Add(dri.DriverObject, Copy(WideString(dri.DriverName), 1, Length(WideString(dri.DriverName))));
    pdei := dri.Devices;
    For J := 0 To dri.DeviceCount - 1 Do
      begin
      dei := pdei^;
      FDeviceMap.Add(dei.DeviceObject, Copy(WideString(dei.Name), 1, Length(WideString(dei.Name))));
      Inc(pdei);
      end;

    Inc(tmp);
    end;

  IRPMonDllSnapshotFree(pdri, count);
  end;
end;

Function TRequestList.GetCount:Integer;
begin
Result := FRequests.Count;
end;

Function TRequestList.GetItem(AIndex:Integer):TDriverRequest;
begin
Result := FRequests[AIndex];
end;

Procedure TRequestList.Clear;
Var
  dr : TDriverRequest;
begin
For dr In FRequests Do
  dr.Free;

FRequests.Clear;
FAllRequests.Clear;
end;

Procedure TRequestList.SetFilterDisplayOnly(AValue:Boolean);
Var
  dr : TDriverRequest;
begin
If FFilterDisplayOnly <> AValue Then
  begin
  FFilterDisplayOnly := AValue;
  FAllRequests.Clear;
  If FFilterDisplayOnly Then
    begin
    For dr In FRequests Do
      FAllRequests.Add(dr);
    end;
  end;
end;

Function TRequestList.ProcessBuffer(ABuffer:PREQUEST_GENERAL):Cardinal;
Var
  keepRequest : Boolean;
  dr : TDriverRequest;
  deviceName : WideString;
  driverName : WideString;
  fileName : WideString;
  processName : WideString;
begin
Result := 0;
While Assigned(ABuffer) Do
  begin
  Case ABuffer.Header.RequestType Of
    ertIRP: dr := TIRPRequest.Build(ABuffer.Irp);
    ertIRPCompletion: dr := TIRPCompleteRequest.Create(ABuffer.IrpComplete);
    ertAddDevice: dr := TAddDeviceRequest.Create(ABuffer.AddDevice);
    ertDriverUnload: dr := TDriverUnloadRequest.Create(ABuffer.DriverUnload);
    ertFastIo: dr := TFastIoRequest.Create(ABuffer.FastIo);
    ertStartIo: dr := TStartIoRequest.Create(ABuffer.StartIo);
    ertDriverDetected : begin
      dr := TDriverDetectedRequest.Create(ABuffer.DriverDetected);
      If FDriverMap.ContainsKey(dr.DriverObject) Then
        FDriverMap.Remove(dr.DriverObject);

      FDriverMap.Add(dr.DriverObject, dr.DriverName);
      end;
    ertDeviceDetected : begin
      dr := TDeviceDetectedRequest.Create(ABuffer.DeviceDetected);
      If FDeviceMap.ContainsKey(dr.DeviceObject) Then
        FDeviceMap.Remove(dr.DeviceObject);

      FDeviceMap.Add(dr.DeviceObject, dr.DeviceName);
      end;
    ertFileObjectNameAssigned : begin
      dr := TFileObjectNameAssignedRequest.Create(ABuffer.FileObjectNameAssigned);
      If FFileMap.ContainsKey(dr.FileObject) Then
        FFileMap.Remove(dr.FileObject);

      FFileMap.Add(dr.FileObject, dr.FileName);
      end;
    ertFileObjectNameDeleted : begin
      dr := TFileObjectNameDeletedRequest.Create(ABuffer.FileObjectNameDeleted);
      If FFileMap.ContainsKey(dr.FileObject) Then
        begin
        dr.SetFileName(FFileMap.Items[dr.FileObject]);
        FFileMap.Remove(dr.FileObject);
        end;
      end;
    ertProcessCreated : begin
      dr := TProcessCreatedRequest.Create(ABuffer.ProcessCreated);
      If FProcessMap.ContainsKey(Cardinal(dr.DriverObject)) Then
        FProcessMap.Remove(Cardinal(dr.DriverObject));

      FProcessMap.Add(Cardinal(dr.DriverObject), dr.DriverName);
      end;
    ertProcessExitted : dr := TProcessExittedRequest.Create(ABuffer.ProcessExitted);
    ertImageLoad : begin
      dr := TImageLoadRequest.Create(ABuffer.ImageLoad);
      If FFileMap.ContainsKey(dr.FileObject) Then
        FFileMap.Remove(dr.FileObject);

      FFileMap.Add(dr.FileObject, dr.FileName);
      end;
    Else dr := TDriverRequest.Create(ABuffer.Header);
    end;

  If FDriverMap.TryGetValue(dr.DriverObject, driverName) Then
    dr.DriverName := driverName;

  If FDeviceMap.TryGetValue(dr.DeviceObject, deviceName) Then
    dr.DeviceName := deviceName;

  If FFileMap.TryGetValue(dr.FileObject, fileName) Then
    dr.SetFileName(fileName);

  If FProcessMap.TryGetValue(dr.ProcessId, processName) Then
    dr.SetProcessName(processName);

  If FFilterDisplayOnly Then
    FAllRequests.Add(dr);

  keepRequest := True;
  If Assigned(FOnRequestProcessed) Then
    FOnRequestProcessed(Self, dr, keepRequest);

  If keepRequest Then
    FRequests.Add(dr)
  Else If Not FFilterDisplayOnly Then
    dr.Free;

  If Not Assigned(ABuffer.Header.Next) Then
    Break;

  ABuffer := PREQUEST_GENERAL(NativeUInt(ABuffer) + RequestGetSize(@ABuffer.Header));
  end;
end;

Procedure TRequestList.SaveToStream(AStream:TStream; AFormat:ERequestLogFormat; ACompress:Boolean = False);
Var
  bh : TBinaryLogHeader;
  I : Integer;
  dr : TDriverRequest;
  comma : AnsiChar;
  arrayChar : AnsiChar;
  newLine : Packed Array [0..1] Of AnsiChar;
begin
comma := ',';
newLine[0] := #13;
newLine[1] := #10;
Case AFormat Of
  rlfBinary: begin
    TBinaryLogHeader.Fill(bh);
    AStream.Write(bh, SizeOf(bh));
    end;
  rlfJSONArray : begin
    arrayChar := '[';
    AStream.Write(arrayChar, SizeOf(arrayChar));
    end;
  end;

For I := 0 To FRequests.Count - 1 Do
  begin
  dr := FRequests[I];
  dr.SaveToStream(AStream, FParsers, AFormat, ACompress);
  If I < FRequests.Count - 1 Then
    begin
    Case AFormat Of
      rlfJSONArray : AStream.Write(comma, SizeOf(comma));
      rlfText,
      rlfJSONLines : AStream.Write(newLine, SizeOf(newLine));
      end;
    end;
  end;

If AFormat = rlfJSONArray Then
  begin
  arrayChar := ']';
  AStream.Write(arrayChar, SizeOf(arrayChar));
  end;
end;

Procedure TRequestList.SaveToFile(AFileName:WideString; AFormat:ERequestLogFormat; ACompress:Boolean = False);
Var
  F : TFileStream;
begin
F := TFileStream.Create(AFileName, fmCreate Or fmOpenWrite);
Try
  SaveToStream(F, AFormat, ACompress);
Finally
  F.Free;
  end;
end;

Procedure TRequestList.LoadFromStream(AStream:TStream; ARequireHeader:Boolean = True);
Var
  reqSize : Cardinal;
  rg : PREQUEST_GENERAL;
  bh : TBinaryLogHeader;
  oldPos : Int64;
  invalidHeader : Boolean;
begin
invalidHeader := False;
oldPos := AStream.Position;
AStream.Read(bh, SizeOf(bh));
If Not TBinaryLogHeader.SignatureValid(bh) Then
  begin
  invalidHeader := True;
  If ARequireHeader Then
    Raise Exception.Create('Invalid log file signature');
  end;

If Not TBinaryLogHeader.VersionSupported(bh) Then
  begin
  invalidHeader := True;
  If ARequireHeader Then
    Raise Exception.Create('Log file version not supported');
  end;

If Not TBinaryLogHeader.ArchitectureSupported(bh) Then
  begin
  invalidHeader := True;
  If ARequireHeader Then
    Raise Exception.Create('The log file and application "bitness"  differ.'#13#10'Use other application version');
  end;

If invalidHeader Then
  AStream.Position := oldPos;

While AStream.Position < AStream.Size Do
  begin
  AStream.Read(reqSize, SizeOf(reqSize));
  rg := AllocMem(reqSize);
  If Not Assigned(rg) Then
    Raise Exception.Create(Format('Unable to allocate %u bytes for request', [reqSize]));

  AStream.Read(rg^, reqSize);
  ProcessBuffer(rg);
  FreeMem(rg);
  end;
end;

Procedure TRequestList.LoadFromFile(AFileName:WideString; ARequireHeader:Boolean = True);
Var
  F : TFileStream;
begin
F := TFileStream.Create(AFileName, fmOpenRead);
Try
  LoadFromStream(F, ARequireHeader);
Finally
  F.Free;
  end;
end;

Procedure TRequestList.Reevaluate;
Var
  store : Boolean;
  I : Integer;
  dr : TDriverRequest;
begin
If Not FFilterDisplayOnly Then
  begin
  I := 0;
  While (I < FRequests.Count) Do
    begin
    If Assigned(FOnRequestProcessed) Then
      begin
      store := True;
      FOnRequestProcessed(Self, FRequests[I], store);
      If Not store THen
        begin
        FRequests[I].Free;
        FRequests.Delete(I);
        Continue;
        end;
      end;

    Inc(I);
    end;
  end
Else begin
  FRequests.Clear;
  For dr In FAllRequests Do
    begin
    store := True;
    If Assigned(FOnRequestProcessed) Then
      FOnRequestProcessed(Self, dr, store);

    If store Then
      FRequests.Add(dr);
    end;
  end;
end;

Function TRequestList.GetTotalCount:Integer;
begin
Result := FRequests.Count;
If FFilterDisplayOnly Then
  Result := FAllRequests.Count;
end;

Function TRequestList.GetDriverName(AObject:Pointer; Var AName:WideString):Boolean;
begin
Result := FDriverMap.TryGetValue(AObject, AName);
end;

Function TRequestList.GetDeviceName(AObject:Pointer; Var AName:WideString):Boolean;
begin
Result := FDeviceMap.TryGetValue(AObject, AName);
end;

Function TRequestList.GetFileName(AObject:Pointer; Var AName:WideString):Boolean;
begin
Result := FFileMap.TryGetValue(AObject, AName);
end;

Function TRequestList.GetProcessName(AProcessId:Cardinal; Var AName:WideString):Boolean;
begin
Result := FProcessMap.TryGetValue(AProcessId, AName);
end;


End.

