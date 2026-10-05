//! A small late-bound COM server. ASP owns rendering; Rust returns data objects.
#![cfg(windows)]
#![allow(non_snake_case)]
use std::{
    ffi::c_void,
    mem::ManuallyDrop,
    panic::{AssertUnwindSafe, catch_unwind},
    path::PathBuf,
    ptr,
};
use taskboard::{Store, Task};
use windows::{
    Win32::{
        Foundation::*,
        System::{Com::*, Variant::*},
    },
    core::*,
};

pub const CLSID_TASKBOARD: GUID = GUID::from_u128(0x2d825abd_3ce3_4694_9ef5_9e46ad821eb0);

enum Value {
    Board(PathBuf),
    Tasks(Vec<Task>),
    Task(Task),
}
#[implement(IDispatch)]
struct Automation {
    value: Value,
}
fn object(value: Value) -> IDispatch {
    Automation { value }.into()
}
fn failure(code: HRESULT) -> Error {
    Error::from_hresult(code)
}

impl Automation {
    fn member(&self, name: &str) -> Option<i32> {
        let names: &[&str] = match self.value {
            Value::Board(_) => &[
                "Version", "NewToken", "List", "Add", "Rename", "SetDone", "Delete",
            ],
            Value::Tasks(_) => &["Count", "Item"],
            Value::Task(_) => &["Id", "Title", "Done", "CreatedAt"],
        };
        names
            .iter()
            .position(|n| n.eq_ignore_ascii_case(name))
            .map(|i| i as i32 + 1)
    }
    fn call(&self, member: i32, flags: DISPATCH_FLAGS, args: &[VARIANT]) -> Result<VARIANT> {
        let (count, method) = match (&self.value, member) {
            (Value::Board(_), 1) => (0, false),
            (Value::Board(_), 2) => (0, true),
            (Value::Board(_), 3 | 4 | 7) => (1, true),
            (Value::Board(_), 5 | 6) => (2, true),
            (Value::Tasks(_), 1) => (0, false),
            (Value::Tasks(_), 2) => (1, true),
            (Value::Task(_), 1..=4) => (0, false),
            _ => return Err(failure(DISP_E_MEMBERNOTFOUND)),
        };
        let expected = if method {
            DISPATCH_METHOD
        } else {
            DISPATCH_PROPERTYGET
        };
        if flags.0 & expected.0 == 0 || flags.0 & !(DISPATCH_METHOD.0 | DISPATCH_PROPERTYGET.0) != 0
        {
            return Err(failure(DISP_E_MEMBERNOTFOUND));
        }
        if args.len() != count {
            return Err(failure(DISP_E_BADPARAMCOUNT));
        }
        // COM stores positional arguments in reverse order. Normalize once here.
        let arg = |index: usize| &args[args.len() - 1 - index];
        match (&self.value, member) {
            (Value::Board(_), 1) => Ok(VARIANT::from(concat!(
                "Rusty ASP ",
                env!("CARGO_PKG_VERSION")
            ))),
            (Value::Board(_), 2) => Ok(VARIANT::from(uuid::Uuid::new_v4().to_string().as_str())),
            (Value::Board(path), id) => {
                let db = Store::open(path).map_err(domain_error)?;
                match id {
                    3 => Ok(object(Value::Tasks(
                        db.list(&string(arg(0))?).map_err(domain_error)?,
                    ))
                    .into()),
                    4 => Ok(db.add(&string(arg(0))?).map_err(domain_error)?.into()),
                    5 => {
                        db.rename(integer(arg(0))?, &string(arg(1))?)
                            .map_err(domain_error)?;
                        Ok(true.into())
                    }
                    6 => {
                        db.set_done(integer(arg(0))?, boolean(arg(1))?)
                            .map_err(domain_error)?;
                        Ok(true.into())
                    }
                    7 => {
                        db.delete(integer(arg(0))?).map_err(domain_error)?;
                        Ok(true.into())
                    }
                    _ => Err(failure(DISP_E_MEMBERNOTFOUND)),
                }
            }
            (Value::Tasks(tasks), 1) => Ok((tasks.len() as i32).into()),
            (Value::Tasks(tasks), 2) => {
                let index = integer(arg(0))?;
                let task = usize::try_from(index)
                    .ok()
                    .and_then(|i| tasks.get(i))
                    .ok_or_else(|| failure(DISP_E_BADINDEX))?;
                Ok(object(Value::Task(task.clone())).into())
            }
            (Value::Task(task), 1) => Ok(task.id.into()),
            (Value::Task(task), 2) => Ok(task.title.as_str().into()),
            (Value::Task(task), 3) => Ok(task.done.into()),
            (Value::Task(task), 4) => Ok(task.created_at.as_str().into()),
            _ => Err(failure(DISP_E_MEMBERNOTFOUND)),
        }
    }
}
fn domain_error(error: taskboard::Error) -> Error {
    Error::new(E_INVALIDARG, error.to_string())
}
fn convert(value: &VARIANT, target: VARENUM) -> Result<VARIANT> {
    unsafe {
        let mut indirect = VARIANT::default();
        VariantCopyInd(&mut indirect, value)?;
        let mut converted = VARIANT::default();
        VariantChangeType(&mut converted, &indirect, VAR_CHANGE_FLAGS(0), target)
            .map_err(|_| failure(DISP_E_TYPEMISMATCH))?;
        Ok(converted)
    }
}
fn string(value: &VARIANT) -> Result<String> {
    let converted = convert(value, VT_BSTR)?;
    // SAFETY: conversion established VT_BSTR; read the BSTR while its owner lives.
    unsafe { Ok(converted.Anonymous.Anonymous.Anonymous.bstrVal.to_string()) }
}
fn integer(value: &VARIANT) -> Result<i32> {
    i32::try_from(&convert(value, VT_I4)?)
}
fn boolean(value: &VARIANT) -> Result<bool> {
    bool::try_from(&convert(value, VT_BOOL)?)
}

impl IDispatch_Impl for Automation_Impl {
    fn GetTypeInfoCount(&self) -> Result<u32> {
        Ok(0)
    }
    fn GetTypeInfo(&self, _: u32, _: u32) -> Result<ITypeInfo> {
        Err(failure(DISP_E_BADINDEX))
    }
    fn GetIDsOfNames(
        &self,
        riid: *const GUID,
        names: *const PCWSTR,
        count: u32,
        _: u32,
        ids: *mut i32,
    ) -> Result<()> {
        catch_unwind(AssertUnwindSafe(|| unsafe {
            if riid.is_null() || names.is_null() || ids.is_null() {
                return Err(failure(E_POINTER));
            }
            if *riid != GUID::zeroed() {
                return Err(failure(DISP_E_UNKNOWNINTERFACE));
            }
            if count == 0 {
                return Err(failure(E_INVALIDARG));
            }
            for i in 0..count as usize {
                *ids.add(i) = -1;
            }
            // Named parameters are deliberately unsupported, as are unknown members.
            if count != 1 || (*names).is_null() {
                return Err(failure(DISP_E_UNKNOWNNAME));
            }
            let name = (*names)
                .to_string()
                .map_err(|_| failure(DISP_E_UNKNOWNNAME))?;
            *ids = self
                .member(&name)
                .ok_or_else(|| failure(DISP_E_UNKNOWNNAME))?;
            Ok(())
        }))
        .unwrap_or_else(|_| Err(failure(E_UNEXPECTED)))
    }
    fn Invoke(
        &self,
        member: i32,
        riid: *const GUID,
        _: u32,
        flags: DISPATCH_FLAGS,
        params: *const DISPPARAMS,
        result: *mut VARIANT,
        exception: *mut EXCEPINFO,
        arg_error: *mut u32,
    ) -> Result<()> {
        let outcome = catch_unwind(AssertUnwindSafe(|| unsafe {
            if !result.is_null() {
                result.write(VARIANT::default());
            }
            if !exception.is_null() {
                exception.write(EXCEPINFO::default());
            }
            if !arg_error.is_null() {
                *arg_error = 0;
            }
            if riid.is_null() || params.is_null() {
                return Err(failure(E_POINTER));
            }
            if *riid != GUID::zeroed() {
                return Err(failure(DISP_E_UNKNOWNINTERFACE));
            }
            let params = &*params;
            if params.cNamedArgs != 0 {
                return Err(failure(DISP_E_NONAMEDARGS));
            }
            if params.cArgs > 2 {
                return Err(failure(DISP_E_BADPARAMCOUNT));
            }
            let args = if params.cArgs == 0 {
                &[]
            } else {
                if params.rgvarg.is_null() {
                    return Err(failure(E_POINTER));
                }
                std::slice::from_raw_parts(params.rgvarg, params.cArgs as usize)
            };
            self.call(member, flags, args)
        }))
        .unwrap_or_else(|_| {
            Err(Error::new(
                E_UNEXPECTED,
                "Unexpected error in the Rust component.",
            ))
        });
        match outcome {
            Ok(value) => {
                if !result.is_null() {
                    unsafe {
                        result.write(value);
                    }
                }
                Ok(())
            }
            Err(error) if error.code() == E_INVALIDARG || error.code() == E_UNEXPECTED => {
                if !exception.is_null() {
                    unsafe {
                        exception.write(EXCEPINFO {
                            bstrSource: ManuallyDrop::new(BSTR::from("RustyAsp.TaskBoard")),
                            bstrDescription: ManuallyDrop::new(BSTR::from(error.message())),
                            scode: error.code().0,
                            ..Default::default()
                        });
                    }
                }
                Err(failure(DISP_E_EXCEPTION))
            }
            Err(error) => Err(error),
        }
    }
}

#[implement(IClassFactory)]
struct Factory;
impl IClassFactory_Impl for Factory_Impl {
    fn CreateInstance(
        &self,
        outer: Ref<IUnknown>,
        iid: *const GUID,
        out: *mut *mut c_void,
    ) -> Result<()> {
        catch_unwind(AssertUnwindSafe(|| unsafe {
            if iid.is_null() || out.is_null() { return Err(failure(E_POINTER)); }
            *out = ptr::null_mut();
            if !outer.is_none() { return Err(failure(CLASS_E_NOAGGREGATION)); }
            let path = std::env::var_os("RUSTY_ASP_DATABASE").map(PathBuf::from)
                .filter(|p| p.is_absolute()).ok_or_else(|| Error::new(E_FAIL, "Set RUSTY_ASP_DATABASE to an absolute SQLite file path before starting IIS."))?;
            object(Value::Board(path)).query(iid, out).ok()
        })).unwrap_or_else(|_| Err(failure(E_UNEXPECTED)))
    }
    fn LockServer(&self, _: BOOL) -> Result<()> {
        Ok(())
    }
}

/// # Safety
/// COM supplies valid, aligned CLSID/IID pointers and writable output storage.
#[unsafe(no_mangle)]
pub unsafe extern "system" fn DllGetClassObject(
    clsid: *const GUID,
    iid: *const GUID,
    out: *mut *mut c_void,
) -> HRESULT {
    catch_unwind(|| unsafe {
        if clsid.is_null() || iid.is_null() || out.is_null() {
            return E_POINTER;
        }
        *out = ptr::null_mut();
        if *clsid != CLSID_TASKBOARD {
            return CLASS_E_CLASSNOTAVAILABLE;
        }
        let factory: IClassFactory = Factory.into();
        factory.query(iid, out)
    })
    .unwrap_or(E_UNEXPECTED)
}
// Conservative unloading policy: the host owns this DLL until process exit.
// Restart IIS Express before replacing a build; no live code is unloaded.
#[unsafe(no_mangle)]
pub extern "system" fn DllCanUnloadNow() -> HRESULT {
    S_FALSE
}

#[cfg(test)]
mod tests {
    use super::*;
    fn invoke(
        value: &IDispatch,
        name: PCWSTR,
        flags: DISPATCH_FLAGS,
        mut args: Vec<VARIANT>,
    ) -> Result<VARIANT> {
        let mut id = 0;
        let mut result = VARIANT::default();
        let iid = GUID::zeroed();
        unsafe {
            value.GetIDsOfNames(&iid, &name, 1, 0, &mut id)?;
            args.reverse();
            let parameters = DISPPARAMS {
                rgvarg: args.as_mut_ptr(),
                cArgs: args.len() as u32,
                ..Default::default()
            };
            value.Invoke(
                id,
                &iid,
                0,
                flags,
                &parameters,
                Some(&mut result),
                None,
                None,
            )?;
        }
        Ok(result)
    }
    #[test]
    fn data_objects_are_callable_through_idispatch() {
        let row = Task {
            id: 17,
            title: "Rust 🦀 <b>data</b>".into(),
            done: true,
            created_at: "2026-10-05T00:00:00Z".into(),
        };
        let collection = object(Value::Tasks(vec![row.clone()]));
        assert_eq!(
            integer(&invoke(&collection, w!("cOuNt"), DISPATCH_PROPERTYGET, vec![]).unwrap())
                .unwrap(),
            1
        );
        let result = invoke(&collection, w!("Item"), DISPATCH_METHOD, vec![0.into()]).unwrap();
        let item = IDispatch::try_from(&result).unwrap();
        assert_eq!(
            string(&invoke(&item, w!("Title"), DISPATCH_PROPERTYGET, vec![]).unwrap()).unwrap(),
            row.title
        );
        assert!(
            boolean(&invoke(&item, w!("Done"), DISPATCH_PROPERTYGET, vec![]).unwrap()).unwrap()
        );
        assert!(invoke(&collection, w!("Item"), DISPATCH_METHOD, vec![(-1).into()]).is_err());
        assert!(invoke(&item, w!("Missing"), DISPATCH_PROPERTYGET, vec![]).is_err());
        assert!(invoke(&item, w!("Title"), DISPATCH_PROPERTYPUT, vec![]).is_err());
        assert!(invoke(&item, w!("Title"), DISPATCH_PROPERTYGET, vec![1.into()]).is_err());
    }
    #[test]
    fn factory_rejects_unknown_classes_and_null_pointers() {
        let mut out = ptr::null_mut();
        unsafe {
            assert_eq!(
                DllGetClassObject(&GUID::zeroed(), &IClassFactory::IID, &mut out),
                CLASS_E_CLASSNOTAVAILABLE
            );
            assert!(out.is_null());
            assert_eq!(
                DllGetClassObject(ptr::null(), &IClassFactory::IID, &mut out),
                E_POINTER
            );
            assert_eq!(
                DllGetClassObject(&CLSID_TASKBOARD, &IClassFactory::IID, &mut out),
                S_OK
            );
            drop(IClassFactory::from_raw(out));
        }
    }
}
