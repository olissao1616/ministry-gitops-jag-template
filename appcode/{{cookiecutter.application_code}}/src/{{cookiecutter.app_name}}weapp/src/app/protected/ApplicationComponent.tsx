"use client";
import { useMemo, useState } from 'react';
import { redirect, useRouter } from 'next/navigation'
import {
  MaterialReactTable,
  useMaterialReactTable,
  type MRT_ColumnDef,
  type MRT_RowSelectionState,
} from 'material-react-table';
import { type_application } from './data-types';
import {
  Box,
  Button,
  lighten,
} from '@mui/material';
import GenericDialog from '../_nonRoutingAssets/components/shared/ModalDialog';
import DialogActionButton from '../_nonRoutingAssets/components/shared/DialogActionButton';
import WarningIcon from '@mui/icons-material/WarningAmberOutlined';
import { selectedApplicationAtom } from '../_nonRoutingAssets/store/atoms';
import { signOut } from "next-auth/react";
import { useAtom } from 'jotai';
import { useQuery } from '@tanstack/react-query';
import { getApplicationData } from '@/app/protected/actions';
import { URL_AGENCY_SELECT } from '../_nonRoutingAssets/types/const';
import { ToastError } from '../_nonRoutingAssets/toastProvider/ToastProvider';

const QUERYKEY = 'applications';

export default function ApplicationTable () {
  const [selectedApplication, setSelectedApplication] = useAtom(selectedApplicationAtom);
  const [selectedRow, setSelectedRow] = useState<any>({});  // may use
  const[open, setOpen] = useState(false);

  const [rowSelection, setRowSelection] = useState<MRT_RowSelectionState>({});
    const columns = useMemo<MRT_ColumnDef<type_application>[]> (
      () => [
        {
          accessorKey: 'description',
          header: 'Application Name',
          size: 450,
        },
      ],
      [],
    );
  
    //call READ hook
    const {
      data: fetchedData = [],
      isError: isLoadingDataError,
      isFetching: isFetchingData,
      isLoading: isLoadingData,
    } = useGetData();
    const router = useRouter();

    const handleDialogOpen = (row: type_application) => {
      setOpen(true);
      setSelectedRow(row);
      // console.log('selectedRow', row);
    };

    const handleDialogClose = (result: boolean = false) => {
      if (result) {
        setOpen(false);
        setSelectedApplication(selectedRow);
      } else {
        signOut();
      }
    };

    const auditWarning = "This action will be audited. Are you sure you want to proceed?";

    const appTable = useMaterialReactTable({
      columns,
      data: fetchedData,
      enableDensityToggle: false,
      enableFullScreenToggle: false,
      enableGlobalFilter: false,
      enableColumnFilters: true,
      enableHiding: false,
      positionToolbarAlertBanner: 'none',
      //enablePagination: true,
      getRowId: (row) => row.code,
      enableRowSelection: false,
      muiTableBodyRowProps: ({ row }) => ({
        //implement row selection click events manually
        onClick: () => {
          setRowSelection((prev) => ({
            [row.id]: !prev[row.id],
          }))
        }, 
        selected: rowSelection[row.id],
        sx: {
          cursor: 'pointer',
        },
      }),
      onRowSelectionChange: setRowSelection,
      renderBottomToolbar: ({ table }) => {
        const handleAppSelect = () => {
          table.getSelectedRowModel().flatRows.map((row) => {
            handleDialogOpen(row.original);
          });
        };
        return (
          <Box
            sx={(theme) => ({
              backgroundColor: lighten(theme.palette.background.default, 0.05),
              display: 'flex',
              gap: '0.5rem',
              p: '8px',
              justifyContent: 'space-between',
            })}
          >
            <Box sx={{ "{{" }} display: 'flex', gap: '0.5rem', alignItems: 'center' {{ "}}" }}>
              {/* import MRT sub-components */}
              {/* <MRT_GlobalFilterTextField table={table} />
              <MRT_ToggleFiltersButton table={table} /> */}
            </Box>
            <Box>
              <Box sx={{ "{{" }} display: 'flex', gap: '0.5rem' {{ "}}" }}>
                <Button
                  color="primary"
                  disabled={table.getSelectedRowModel().rows.length == 0}
                  //disabled={rowSelection == {}}
                  onClick={handleAppSelect}
                  variant="contained"
                >
                  Select
                </Button>
              </Box>
            </Box>
            <GenericDialog
            open={open}
            // onClose={handleDialogClose}
            onClose={() => handleDialogClose(false)}
            title="Audit Warning"
            icon={<WarningIcon  sx={{ "{{" }} color: 'red' {{ "}}" }}/>}
            content={auditWarning}
            actions={
              <>
                <DialogActionButton color="primary" variant="outlined" onClick={() => handleDialogClose(false)}>Exit application</DialogActionButton>
                <DialogActionButton color="primary" variant="contained" onClick={() => handleDialogClose(true)} autoFocus>I understand</DialogActionButton>
              </>
            }
          />
          </Box>
        );
      },
      state: {
        rowSelection,
        isLoading: isLoadingData,
        showAlertBanner: isLoadingDataError,
        showProgressBars: isFetchingData,
      }
    });

  return (
<div>
    <h4>Welcome to your first react-base app - Select an application to get started</h4>
    <MaterialReactTable table={appTable}></MaterialReactTable>
</div>
  )
};

//READ hook (get dutyType from api)
function useGetData() {
  const router = useRouter();
  const [selectedApplication, setSelectedApplication] = useAtom(selectedApplicationAtom);
  
  return useQuery<type_application[]>({
    queryKey: [QUERYKEY],
    queryFn: async () => {
      const [data, error] = await getApplicationData();
      // if user can only access one application, skip the application select, redirect the user to agency select.
      if (error) {
        ToastError(error);
        return [];
      }
      if (data && data.length == 1) {
        setSelectedApplication(data[0]);
        router.push(URL_AGENCY_SELECT);        
      } 
      return data;
    },
    refetchOnWindowFocus: false,
  });
}