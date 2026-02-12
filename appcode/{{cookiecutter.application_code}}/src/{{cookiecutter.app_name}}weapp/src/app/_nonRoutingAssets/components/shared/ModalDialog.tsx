import React, { ReactNode } from 'react';
import Dialog from '@mui/material/Dialog';
import DialogActions from '@mui/material/DialogActions';
import DialogContent from '@mui/material/DialogContent';
import DialogContentText from '@mui/material/DialogContentText';
import DialogTitle from '@mui/material/DialogTitle';
import CloseIcon from '@mui/icons-material/Close';
import { useTheme } from '@mui/material/styles';
import { DialogProps as MUIDialogProps } from '@mui/material/Dialog';
import { IconButton } from '@mui/material';

interface ModalDialogProps extends MUIDialogProps {
    open: boolean;
    onClose: (result:boolean) => void;
    title: string;
    icon?: ReactNode;
    content: string;
    contentNode?: ReactNode;
    actions: ReactNode;
    showCloseButton?: boolean;
}

const ModalDialog: React.FC<ModalDialogProps> = ({
    open,
    onClose,
    title,
    icon,
    content,
    contentNode,
    actions,
    showCloseButton = true,
    ...dialogProps  // additional ModalDialog props
}) => {
    const theme = useTheme();

    const dialogContent = contentNode ? contentNode : (
        content ? <DialogContentText>{content}</DialogContentText> : null
    );

    return (
        <Dialog
            open={open}
            onClose={onClose}
            {...dialogProps}
            sx={{ "{{" }}
                '& .MuiDialog-paper': {
                    padding: 3,
                    fontSize: '1rem',
                },
            {{ "}}" }}
        >
            {title &&
            <DialogTitle variant='h5' sx={{ "{{" }}padding: 0, display: 'flex', alignItems: 'center', justifyContent: 'space-between', backgroundColor: theme.palette.background.default{{ "}}" }}>
                <div style={{ "{{" }}display: 'flex', alignItems: 'center', flex: '1'{{ "}}" }} >
                    {icon &&
                        <span style={{ "{{" }} marginRight: '0.5rem',  fontSize: 16 {{ "}}" }}>
                            {icon}
                        </span>
                    }
                    <span style={{ "{{" }}fontWeight: 'bold'{{ "}}" }}>
                        {title}
                    </span>
                </div>
                { showCloseButton && (
                    <IconButton aria-label='close' onClick={()=> onClose(false)}
                        sx={{ "{{" }}
                            marginLeft: 'auto',
                            '& .MuiSvgIcon-root': { fontSize: 20 }
                        {{ "}}" }}
                    >
                        <CloseIcon />
                    </IconButton>
                )}
            </DialogTitle>}
            <DialogContent sx={{ "{{" }}padding: 1, fontSize: '1rem'{{ "}}" }}>
                {dialogContent}
            </DialogContent>
            {actions && <DialogActions>{actions}</DialogActions>}
        </Dialog>
    );
};

export default ModalDialog;