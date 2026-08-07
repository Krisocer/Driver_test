#include <ntddk.h>
#include "public.h"

static VOID MyStarterUnload(_In_ PDRIVER_OBJECT DriverObject);
static DRIVER_DISPATCH MyStarterCreateClose;
static DRIVER_DISPATCH MyStarterDeviceControl;
static DRIVER_DISPATCH MyStarterUnsupported;

static NTSTATUS
CompleteRequest(_In_ PIRP Irp, _In_ NTSTATUS Status, _In_ ULONG_PTR Information)
{
    Irp->IoStatus.Status = Status;
    Irp->IoStatus.Information = Information;
    IoCompleteRequest(Irp, IO_NO_INCREMENT);
    return Status;
}

NTSTATUS
DriverEntry(_In_ PDRIVER_OBJECT DriverObject, _In_ PUNICODE_STRING RegistryPath)
{
    UNREFERENCED_PARAMETER(RegistryPath);

    NTSTATUS status;
    PDEVICE_OBJECT deviceObject = NULL;
    UNICODE_STRING deviceName;
    UNICODE_STRING symbolicLink;

    RtlInitUnicodeString(&deviceName, MYSTARTER_DEVICE_NAME);
    RtlInitUnicodeString(&symbolicLink, MYSTARTER_SYMBOLIC_LINK);

    status = IoCreateDevice(
        DriverObject,
        0,
        &deviceName,
        FILE_DEVICE_MYSTARTER,
        FILE_DEVICE_SECURE_OPEN,
        FALSE,
        &deviceObject);

    if (!NT_SUCCESS(status)) {
        KdPrint(("MyStarterDriver: IoCreateDevice failed: 0x%08X\n", status));
        return status;
    }

    status = IoCreateSymbolicLink(&symbolicLink, &deviceName);
    if (!NT_SUCCESS(status)) {
        KdPrint(("MyStarterDriver: IoCreateSymbolicLink failed: 0x%08X\n", status));
        IoDeleteDevice(deviceObject);
        return status;
    }

    for (ULONG i = 0; i <= IRP_MJ_MAXIMUM_FUNCTION; ++i) {
        DriverObject->MajorFunction[i] = MyStarterUnsupported;
    }

    DriverObject->MajorFunction[IRP_MJ_CREATE] = MyStarterCreateClose;
    DriverObject->MajorFunction[IRP_MJ_CLOSE] = MyStarterCreateClose;
    DriverObject->MajorFunction[IRP_MJ_DEVICE_CONTROL] = MyStarterDeviceControl;
    DriverObject->DriverUnload = MyStarterUnload;

    deviceObject->Flags &= ~DO_DEVICE_INITIALIZING;

    KdPrint(("MyStarterDriver: loaded\n"));
    return STATUS_SUCCESS;
}

static VOID
MyStarterUnload(_In_ PDRIVER_OBJECT DriverObject)
{
    UNICODE_STRING symbolicLink;

    RtlInitUnicodeString(&symbolicLink, MYSTARTER_SYMBOLIC_LINK);
    IoDeleteSymbolicLink(&symbolicLink);

    if (DriverObject->DeviceObject != NULL) {
        IoDeleteDevice(DriverObject->DeviceObject);
    }

    KdPrint(("MyStarterDriver: unloaded\n"));
}

static NTSTATUS
MyStarterCreateClose(_In_ PDEVICE_OBJECT DeviceObject, _Inout_ PIRP Irp)
{
    UNREFERENCED_PARAMETER(DeviceObject);
    return CompleteRequest(Irp, STATUS_SUCCESS, 0);
}

static NTSTATUS
MyStarterDeviceControl(_In_ PDEVICE_OBJECT DeviceObject, _Inout_ PIRP Irp)
{
    UNREFERENCED_PARAMETER(DeviceObject);

    PIO_STACK_LOCATION stack = IoGetCurrentIrpStackLocation(Irp);
    ULONG controlCode = stack->Parameters.DeviceIoControl.IoControlCode;

    switch (controlCode) {
    case IOCTL_MYSTARTER_PING:
        KdPrint(("MyStarterDriver: ping\n"));
        return CompleteRequest(Irp, STATUS_SUCCESS, 0);

    default:
        return CompleteRequest(Irp, STATUS_INVALID_DEVICE_REQUEST, 0);
    }
}

static NTSTATUS
MyStarterUnsupported(_In_ PDEVICE_OBJECT DeviceObject, _Inout_ PIRP Irp)
{
    UNREFERENCED_PARAMETER(DeviceObject);
    return CompleteRequest(Irp, STATUS_NOT_SUPPORTED, 0);
}
