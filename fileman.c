#include <dirent.h>
#include <linux/limits.h>
#include <sys/ioctl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <termios.h>
#include <unistd.h>
#define ESC "\033"
#define CLEAR ESC "[2J"      
#define CLEARLINE ESC "[2K"  
#define CLEARTOEND ESC "[0J" 
#define CLEARTOSTART ESC "[1J"
#define BOLD ESC "[1m"
#define UNDERLINE ESC "[4m"
#define ITALIC ESC "[3m"
#define INVERSE ESC "[7m"
#define STRIKETHROUGH ESC "[9m"
#define RESET ESC "[0m"      
#define INVISCURSOR ESC "[?25l" 
#define VISCURSOR ESC "[?25h"
#define UP ESC "[%dA"
#define DOWN ESC "[%dB"
#define RIGHT ESC "[%dC"
#define LEFT ESC "[%dD"
#define MOVETO ESC "[%d;%dH"
#define FRGB ESC "[38;2;%d;%d;%dm"
#define BRGB ESC "[48;2;%d;%d;%dm"
#define ORIGIN ESC "[H"
#define	STDIN_FILENO	0	/* Standard input.  */
#define	STDOUT_FILENO	1	/* Standard output.  */
#define	STDERR_FILENO	2	/* Standard error output.  */
void getDimensions(int *rows, int *cols) {
    struct winsize w;
    if (ioctl(STDOUT_FILENO, TIOCGWINSZ, &w) == -1) {
        perror("ioctl");
        exit(1);
    }
    *rows = w.ws_row;
    *cols = w.ws_col;
}
int getch() {
    struct termios oldt, newt;
    int ch;
    tcgetattr(STDIN_FILENO, &oldt);
    newt = oldt;
    newt.c_lflag &= ~(ICANON | ECHO); 
    tcsetattr(STDIN_FILENO, TCSANOW, &newt); 
    ch = getchar();
    tcsetattr(STDIN_FILENO, TCSANOW, &oldt);
    return ch;
}
void getparent(const char* dir,char* parent) {
    int len=strlen(dir);
    if (len==1) return;
    if (dir[len-1]=='/') len--;
    len--;
    for (;dir[len]!='/';len--);
    for (int i=0;i<len;i++) parent[i]=dir[i];
    if (len!=0) parent[len]=0;
    else {
        parent[0]='/';
        parent[1]=0;
    }
}

int t_size(int *rows, int *cols) {
    struct winsize w;
    if (ioctl(STDOUT_FILENO, TIOCGWINSZ, &w) == -1) {
        return -1;
    }
    *rows = w.ws_row;
    *cols = w.ws_col;
    return 0;
}
#define getsize(x,y) (t_size(&x,&y))
void explore(char* path) {
    printf(CLEAR INVISCURSOR);
    char parent[PATH_MAX+1];
    char selectt[NAME_MAX+1];
    getparent(path,parent);
    char*user=getenv("USER");
    char hostname[HOST_NAME_MAX+1];
    gethostname(hostname,sizeof(hostname));
    int selected=0;
    int c=0;
    int row,cols;
    getsize(row,cols);
    int middle=cols/5;
    int right=cols/2;
    do {
        switch (c) {
            case 'a': case 'h': case 'H': case 'A':
                strcpy(path,parent);
                getparent(path,parent);
                selected=0;
                break;
            case 's': case 'j': case 'J': case 'S':
                selected++;
                break;
            case 'l': case 'd': case 'L': case 'D':
                strcpy(parent,path);
                int i=strlen(path);
                if (path[i-1]!='/') path[i++]='/';
                strcpy(path+i,selectt);
                selected=0;
                break;
            case 'w': case 'W': case 'K': case 'k':
                selected--;
                break;
        }
        printf(CLEAR ORIGIN"  %s@%s  %s",user,hostname,path);
        int i=0;
        DIR* D=opendir(parent);
        DIR* d=opendir(path);
        struct dirent* ent;
        while ((ent=readdir(d))!=NULL) {
            if (ent->d_name[0]!='.') {
                if (strlen(ent->d_name)>cols/2-cols/5) ent->d_name[cols/2-cols/5]=0;
                if (selected==i) {
                    strcpy(selectt,ent->d_name);
                    printf(MOVETO BRGB"%s"RESET,i+3,middle+1,100,100,100,ent->d_name);
                } else printf(MOVETO"%s",i+3,middle+1,ent->d_name);
                i++;
            }
        }
        i=0;
        while ((ent=readdir(D))!=NULL) {
            if (ent->d_name[0]!='.') {
                i++;
                if (strlen(ent->d_name)>cols/5) ent->d_name[cols/5]=0;
                printf(MOVETO"%s",i+3,1,ent->d_name);
            }
        }
        closedir(d);
        closedir(D);
    } while ((c=getch())!='q');
    printf(CLEAR ORIGIN VISCURSOR);
}
int main(int argc,char**argv) {
    char path[PATH_MAX+1];
    if (argc>=2) {
        if (access(argv[1],F_OK)==0) {
            realpath(argv[1],path);
        } else return 1;
    } else {
        char*c=getenv("HOME");
        strcpy(path,c);
    }
    explore(path);
}
