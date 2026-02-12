"use client";
import { useMemo, useState, useRef } from 'react';
import { useRouter } from 'next/navigation'
import {
  MaterialReactTable,
  useMaterialReactTable,
  type MRT_ColumnDef,
  type MRT_RowSelectionState,
} from 'material-react-table';
import { type_agency } from './data-types';
import {
  Box,
  Button,
  lighten,
} from '@mui/material';
import { useAtom } from 'jotai';
import { agenciesAtom, selectedAgencyAtom } from '../../_nonRoutingAssets/store/atoms'; 
import { useQuery } from '@tanstack/react-query';
import { getAgencyData } from './actions';
import { URL_AGENCY_SELECT, URL_APPLICATION_SELECT, URL_MAINMENU } from '@/app/_nonRoutingAssets/types/const';
import { ToastError } from '@/app/_nonRoutingAssets/toastProvider/ToastProvider';

const QUERYKEY = 'agencies';

export default function AgencyTable ({ pNextPath }: { pNextPath : string }) {
  const [selectedAgency, setSelectedAgency] = useAtom(selectedAgencyAtom);
  const [rowSelection, setRowSelection] = useState<MRT_RowSelectionState>({});
  
  //call READ hook
  const {
    data: fetchedData = [],
    isError: isLoadingDataError,
    isFetching: isFetchingData,
    isLoading: isLoadingData,
  } = useGetData();

  const columns = useMemo<MRT_ColumnDef<type_agency>[]> (
    () => [
      {
        accessorKey: 'agencyAssignment.agencyName',
        header: 'Agency Name',
        size: 400,
      },
      {
        accessorKey: 'agencyAssignment.identifierCode',
        header: 'Agency Code',
        size: 300,
      },
    ],
    [],
  );
  const router = useRouter();
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
    getRowId: (row) => row.agencyAssignment?.identifierCode,
    enableRowSelection: false,
    muiTableBodyRowProps: ({ row }) => ({
      //implement row selection click events manually
      onClick: () => {
        setRowSelection((prev) => ({
          [row.id]: !prev[row.id],
        }));
      }, 
      selected: rowSelection[row.id],
      sx: {
        cursor: 'pointer',
      },
    }),
    onRowSelectionChange: setRowSelection,
    renderBottomToolbar: ({ table }) => {
      const handleAgencySelect = () => {
        table.getSelectedRowModel().flatRows.map((row) => {
          //console.log("selected agency name: " + row.original.agencyAssignment.agencyName);
          setSelectedAgency(row.original);
          router.push(!pNextPath ? URL_MAINMENU : pNextPath != URL_AGENCY_SELECT && pNextPath != URL_APPLICATION_SELECT ? pNextPath : URL_MAINMENU);
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
                onClick={handleAgencySelect}
                variant="contained"
              >
                Select
              </Button>
            </Box>
          </Box>
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
      <h5>Select Agency</h5>
      <MaterialReactTable table={appTable}></MaterialReactTable>
    </div>
  ) 
  
};

//READ hook (get dutyType from api)
function useGetData() {
  const [agencies, setAgencies] = useAtom(agenciesAtom);
  return useQuery<type_agency[]>({
    queryKey: [QUERYKEY],
    queryFn: async () => {
      if (!agencies) {
        console.log("first time fetching agency list");
        const [data, error] = await getAgencyData();
        if (error) {
          ToastError(error);
          return [];
        }
        setAgencies(data);
        return data;
      }
      console.log("return stored agencies");
      return agencies;
    },
    refetchOnWindowFocus: false,
  });
}


